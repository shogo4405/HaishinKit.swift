import Accelerate
import AVFoundation

private let kIOAudioMixerTrack_frameCapacity: AVAudioFrameCount = 1024
private let kIOAudioMixerTrack_sampleTime: AVAudioFramePosition = 0

protocol IOAudioMixerTrackDelegate: AnyObject {
    func track(_ track: IOAudioMixerTrack<Self>, didOutput audioPCMBuffer: AVAudioPCMBuffer, when: AVAudioTime)
    func track(_ track: IOAudioMixerTrack<Self>, errorOccurred error: IOAudioUnitError)
}

/// Constraints on the audio mixier track's settings.
public struct IOAudioMixerTrackSettings: Codable {
    /// Specifies the volume for output.
    public var volume: Float = 1.0

    /// Specifies the muted that indicates whether the audio output is muted.
    public var isMuted = false

    /// Specifies the mixes the channels or not. Currently, it supports input sources with 4, 5, 6, and 8 channels.
    public var downmix = true

    /// Specifies the map of the output to input channels.
    /// ## Example code:
    /// ```
    /// // If you want to use the 3rd and 4th channels from a 4-channel input source for a 2-channel output, you would specify it like this.
    /// channelMap = [2, 3]
    /// ```
    public var channelMap: [Int]?

    func apply(_ converter: AVAudioConverter?, oldValue: IOAudioMixerTrackSettings?) {
        guard let converter else {
            return
        }
        if converter.downmix != downmix {
            converter.downmix = downmix
        }
        if let channelMap = validatedChannelMap(converter) {
            converter.channelMap = channelMap.map { NSNumber(value: $0) }
        } else {
            switch converter.outputFormat.channelCount {
            case 1:
                converter.channelMap = [0]
            case 2:
                converter.channelMap = (converter.inputFormat.channelCount == 1) ? [0, 0] : [0, 1]
            default:
                logger.error("channelCount must be 2 or less.")
            }
        }
    }

    private func validatedChannelMap(_ converter: AVAudioConverter) -> [Int]? {
        guard let channelMap, channelMap.count == converter.outputFormat.channelCount else {
            return nil
        }
        for inputChannel in channelMap {
            if inputChannel >= converter.inputFormat.channelCount {
                return nil
            }
        }
        return channelMap
    }
}

final class IOAudioMixerTrack<T: IOAudioMixerTrackDelegate> {
    let id: UInt8
    let outputFormat: AVAudioFormat

    var settings: IOAudioMixerTrackSettings = .init() {
        didSet {
            settings.apply(audioConverter, oldValue: oldValue)
        }
    }
    weak var delegate: T?

    var inputFormat: AVAudioFormat? {
        return audioConverter?.inputFormat
    }
    private var inSourceFormat: CMFormatDescription? {
        didSet {
            guard inSourceFormat != oldValue else {
                return
            }
            setUp(inSourceFormat)
        }
    }
    private var ringBuffer: IOAudioRingBuffer?
    private var inputBuffer: AVAudioPCMBuffer?
    private var outputBuffer: AVAudioPCMBuffer?
    private var audioConverter: AVAudioConverter? {
        didSet {
            guard let audioConverter else {
                return
            }
            settings.apply(audioConverter, oldValue: nil)
            audioConverter.primeMethod = .normal
        }
    }
    private var anchor: AVAudioTime?
    private var sampleTime: AVAudioFramePosition = kIOAudioMixerTrack_sampleTime

    init(id: UInt8, outputFormat: AVAudioFormat) {
        self.id = id
        self.outputFormat = outputFormat
    }

    func append(_ sampleBuffer: CMSampleBuffer) {
        inSourceFormat = sampleBuffer.formatDescription
        guard let inSourceFormat = inSourceFormat?.audioStreamBasicDescription else {
            return
        }
        if sampleTime == kIOAudioMixerTrack_sampleTime {
            let targetSampleTime: CMTimeValue
            if sampleBuffer.presentationTimeStamp.timescale == Int32(inSourceFormat.mSampleRate) {
                targetSampleTime = sampleBuffer.presentationTimeStamp.value
            } else {
                targetSampleTime = Int64(Double(sampleBuffer.presentationTimeStamp.value) * inSourceFormat.mSampleRate / Double(sampleBuffer.presentationTimeStamp.timescale))
            }
            sampleTime = AVAudioFramePosition(targetSampleTime)
            anchor = .init(hostTime: AVAudioTime.hostTime(forSeconds: sampleBuffer.presentationTimeStamp.seconds), sampleTime: sampleTime, atRate: outputFormat.sampleRate)
        }
        ringBuffer?.append(sampleBuffer)
        resample()
    }

    func append(_ audioBuffer: AVAudioPCMBuffer, when: AVAudioTime) {
        inSourceFormat = audioBuffer.format.formatDescription
        if sampleTime == kIOAudioMixerTrack_sampleTime {
            sampleTime = when.sampleTime
            anchor = when
        }
        ringBuffer?.append(audioBuffer, when: when)
        resample()
    }

    @inline(__always)
    private func resample() {
        guard let outputBuffer, let inputBuffer, let ringBuffer else {
            return
        }
        var status: AVAudioConverterOutputStatus? = .endOfStream
        repeat {
            var error: NSError?
            status = audioConverter?.convert(to: outputBuffer, error: &error) { inNumberFrames, status in
                if inNumberFrames <= ringBuffer.counts {
                    _ = ringBuffer.render(inNumberFrames, ioData: inputBuffer.mutableAudioBufferList)
                    inputBuffer.frameLength = inNumberFrames
                    status.pointee = .haveData
                    return inputBuffer
                } else {
                    status.pointee = .noDataNow
                    return nil
                }
            }
            switch status {
            case .haveData:
                let time = AVAudioTime(sampleTime: sampleTime, atRate: outputBuffer.format.sampleRate)
                if let anchor, let when = time.extrapolateTime(fromAnchor: anchor) {
                    delegate?.track(self, didOutput: outputBuffer.volume(settings.volume).muted(settings.isMuted), when: when)
                }
                sampleTime += 1024
            case .error:
                if let error {
                    delegate?.track(self, errorOccurred: .failedToConvert(error: error))
                }
            default:
                break
            }
        } while(status == .haveData)
    }

    private func setUp(_ inSourceFormat: CMFormatDescription?) {
        guard let inputFormat = AVAudioUtil.makeAudioFormat(inSourceFormat) else {
            delegate?.track(self, errorOccurred: .failedToCreate(from: inputFormat, to: outputFormat))
            return
        }
        inputBuffer = .init(pcmFormat: inputFormat, frameCapacity: 1024 * 4)
        ringBuffer = .init(inputFormat)
        outputBuffer = .init(pcmFormat: outputFormat, frameCapacity: kIOAudioMixerTrack_frameCapacity)
        if logger.isEnabledFor(level: .info) {
            logger.info("inputFormat:", inputFormat, ", outputFormat:", outputFormat)
        }
        sampleTime = kIOAudioMixerTrack_sampleTime
        audioConverter = .init(from: inputFormat, to: outputFormat)
    }
}
