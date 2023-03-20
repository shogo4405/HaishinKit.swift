import AVFoundation

/**
 * The interface a AudioCodec uses to inform its delegate.
 */
public protocol AudioCodecDelegate: AnyObject {
    /// Tells the receiver to output an AVAudioFormat.
    func audioCodec(_ codec: AudioCodec, didOutput audioFormat: AVAudioFormat)
    /// Tells the receiver to output an encoded or decoded CMSampleBuffer.
    func audioCodec(_ codec: AudioCodec, didOutput audioBuffer: AVAudioBuffer, presentationTimeStamp: CMTime)
    /// Tells the receiver to occured an error.
    func audioCodec(_ codec: AudioCodec, errorOccurred error: AudioCodec.Error)
}

// MARK: -
/**
 * The AudioCodec translate audio data to another format.
 * - seealso: https://developer.apple.com/library/ios/technotes/tn2236/_index.html
 */
public class AudioCodec {
    /// The AudioCodec  error domain codes.
    public enum Error: Swift.Error {
        case failedToCreate(from: AVAudioFormat, to: AVAudioFormat)
        case failedToConvert(error: NSError)
    }
    /// Specifies the output format.
    public var destination: AudioCodecFormat = .aac
    /// Specifies the delegate.
    public weak var delegate: AudioCodecDelegate?
    /// This instance is running to process(true) or not(false).
    public private(set) var isRunning: Atomic<Bool> = .init(false)
    /// Specifies the settings for audio codec.
    public var settings: AudioCodecSettings = .default {
        didSet {
            settings.apply(audioConverter, oldValue: oldValue)
        }
    }
    var effects: Set<AudioEffect> = []
    var lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.AudioCodec.lock")
    var inSourceFormat: AudioStreamBasicDescription? {
        didSet {
            guard var inSourceFormat, inSourceFormat != oldValue else {
                return
            }
            outputBuffers.removeAll()
            ringBuffer = .init(&inSourceFormat)
            audioConverter = makeAudioConverter(&inSourceFormat)
        }
    }
    private var ringBuffer: AudioCodecRingBuffer?
    private var outputBuffers: [AVAudioBuffer] = []
    private var audioConverter: AVAudioConverter?

    /// Append a CMSampleBuffer.
    public func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer, offset: Int = 0) {
        guard CMSampleBufferDataIsReady(sampleBuffer), isRunning.value else {
            return
        }
        switch destination {
        case .aac:
            guard let audioConverter, let ringBuffer else {
                return
            }
            let numSamples = ringBuffer.appendSampleBuffer(sampleBuffer, offset: offset)
            if ringBuffer.isReady {
                guard let buffer = getOutputBuffer() else {
                    return
                }
                for effect in effects {
                    effect.execute(ringBuffer.current, presentationTimeStamp: ringBuffer.presentationTimeStamp)
                }
                var error: NSError?
                audioConverter.convert(to: buffer, error: &error) { _, status in
                    status.pointee = .haveData
                    return ringBuffer.current
                }
                if let error {
                    delegate?.audioCodec(self, errorOccurred: .failedToConvert(error: error))
                } else {
                    delegate?.audioCodec(self, didOutput: buffer, presentationTimeStamp: ringBuffer.presentationTimeStamp)
                }
                ringBuffer.next()
            }
            if offset + numSamples < sampleBuffer.numSamples {
                appendSampleBuffer(sampleBuffer, offset: offset + numSamples)
            }
        case .pcm:
            var offset = 0
            var presentationTimeStamp = sampleBuffer.presentationTimeStamp
            for i in 0..<sampleBuffer.numSamples {
                guard let buffer = makeInputBuffer() as? AVAudioCompressedBuffer else {
                    continue
                }
                let sampleSize = CMSampleBufferGetSampleSize(sampleBuffer, at: i)
                let byteCount = sampleSize - ADTSHeader.size
                buffer.packetDescriptions?.pointee = AudioStreamPacketDescription(mStartOffset: 0, mVariableFramesInPacket: 0, mDataByteSize: UInt32(byteCount))
                buffer.packetCount = 1
                buffer.byteLength = UInt32(byteCount)
                if let blockBuffer = sampleBuffer.dataBuffer {
                    CMBlockBufferCopyDataBytes(blockBuffer, atOffset: offset + ADTSHeader.size, dataLength: byteCount, destination: buffer.data)
                    appendAudioBuffer(buffer, presentationTimeStamp: presentationTimeStamp)
                    presentationTimeStamp = CMTimeAdd(presentationTimeStamp, CMTime(value: CMTimeValue(1024), timescale: sampleBuffer.presentationTimeStamp.timescale))
                    offset += sampleSize
                }
            }
        }
    }

    func appendAudioBuffer(_ audioBuffer: AVAudioBuffer, presentationTimeStamp: CMTime) {
        guard isRunning.value, let audioConverter, let buffer = getOutputBuffer() else {
            return
        }
        var error: NSError?
        audioConverter.convert(to: buffer, error: &error) { _, status in
            status.pointee = .haveData
            return audioBuffer
        }
        if let error {
            delegate?.audioCodec(self, errorOccurred: .failedToConvert(error: error))
        } else {
            delegate?.audioCodec(self, didOutput: buffer, presentationTimeStamp: presentationTimeStamp)
        }
    }

    func makeInputBuffer() -> AVAudioBuffer? {
        guard let inputFormat = audioConverter?.inputFormat else {
            return nil
        }
        switch inSourceFormat?.mFormatID {
        case kAudioFormatLinearPCM:
            return AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: 1024)
        default:
            return AVAudioCompressedBuffer(format: inputFormat, packetCapacity: 1, maximumPacketSize: 1024)
        }
    }

    func releaseOutputBuffer(_ buffer: AVAudioBuffer) {
        outputBuffers.append(buffer)
    }

    private func getOutputBuffer() -> AVAudioBuffer? {
        guard let outputFormat = audioConverter?.outputFormat else {
            return nil
        }
        if outputBuffers.isEmpty {
            return destination.makeAudioBuffer(outputFormat)
        }
        return outputBuffers.removeFirst()
    }

    private func makeAudioConverter(_ inSourceFormat: inout AudioStreamBasicDescription) -> AVAudioConverter? {
        guard
            let inputFormat = AVAudioFormat(streamDescription: &inSourceFormat),
            let outputFormat = destination.makeAudioFormat(inSourceFormat) else {
            return nil
        }
        let converter = AVAudioConverter(from: inputFormat, to: outputFormat)
        settings.apply(converter, oldValue: nil)
        if converter == nil {
            delegate?.audioCodec(self, errorOccurred: .failedToCreate(from: inputFormat, to: outputFormat))
        } else {
            delegate?.audioCodec(self, didOutput: outputFormat)
        }
        return converter
    }
}

extension AudioCodec: Running {
    // MARK: Running
    public func startRunning() {
        lockQueue.async {
            guard !self.isRunning.value else {
                return
            }
            if let audioConverter = self.audioConverter {
                self.delegate?.audioCodec(self, didOutput: audioConverter.outputFormat)
            }
            self.isRunning.mutate { $0 = true }
        }
    }

    public func stopRunning() {
        lockQueue.async {
            guard self.isRunning.value else {
                return
            }
            self.inSourceFormat = nil
            self.audioConverter = nil
            self.ringBuffer = nil
            self.isRunning.mutate { $0 = false }
        }
    }
}
