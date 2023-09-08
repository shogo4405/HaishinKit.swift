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
    private static let frameCapacity: UInt32 = 1024

    /// The AudioCodec  error domain codes.
    public enum Error: Swift.Error {
        case failedToCreate(from: AVAudioFormat?, to: AVAudioFormat?)
        case failedToConvert(error: NSError)
    }

    /// Specifies the delegate.
    public weak var delegate: (any AudioCodecDelegate)?
    /// This instance is running to process(true) or not(false).
    public private(set) var isRunning: Atomic<Bool> = .init(false)
    /// Specifies the settings for audio codec.
    public var settings: AudioCodecSettings = .default {
        didSet {
            settings.apply(audioConverter, oldValue: oldValue)
        }
    }
    var lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.AudioCodec.lock")
    var inSourceFormat: AudioStreamBasicDescription? {
        didSet {
            guard var inSourceFormat, inSourceFormat != oldValue else {
                return
            }
            inputBuffers.removeAll()
            outputBuffers.removeAll()
            audioConverter = makeAudioConverter(&inSourceFormat)
            for _ in 0..<settings.format.bufferCounts {
                if let inputBuffer = makeInputBuffer() {
                    inputBuffers.append(inputBuffer)
                }
            }
        }
    }
    private var cursor: Int = 0
    private var inputBuffers: [AVAudioBuffer] = []
    private var outputBuffers: [AVAudioBuffer] = []
    private var audioConverter: AVAudioConverter?

    /// Append a CMSampleBuffer.
    public func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard isRunning.value else {
            return
        }
        switch settings.format {
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
        default:
            break
        }
    }

    func appendAudioBuffer(_ audioBuffer: AVAudioBuffer, presentationTimeStamp: CMTime) {
        guard let audioConverter, isRunning.value else {
            return
        }
        var error: NSError?
        let outputBuffer = self.outputBuffer
        let outputStatus = audioConverter.convert(to: outputBuffer, error: &error) { _, inputStatus in
            switch self.inputBuffer {
            case let inputBuffer as AVAudioPCMBuffer:
                if !inputBuffer.copy(audioBuffer) {
                    inputBuffer.muted()
                }
            default:
                break
            }
            inputStatus.pointee = .haveData
            return self.inputBuffer
        }
        switch outputStatus {
        case .haveData:
            delegate?.audioCodec(self, didOutput: outputBuffer, presentationTimeStamp: presentationTimeStamp)
        case .error:
            if let error {
                delegate?.audioCodec(self, errorOccurred: .failedToConvert(error: error))
            }
        default:
            break
        }
        cursor += 1
        if cursor == inputBuffers.count {
            cursor = 0
        }
    }

    private func makeInputBuffer() -> AVAudioBuffer? {
        guard let inputFormat = audioConverter?.inputFormat else {
            return nil
        }
        switch inSourceFormat?.mFormatID {
        case kAudioFormatLinearPCM:
            let buffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: Self.frameCapacity)
            buffer?.frameLength = Self.frameCapacity
            return buffer
        default:
            return AVAudioCompressedBuffer(format: inputFormat, packetCapacity: 1, maximumPacketSize: 1024)
        }
    }

    private func makeAudioConverter(_ inSourceFormat: inout AudioStreamBasicDescription) -> AVAudioConverter? {
        guard
            let inputFormat = AVAudioFormatFactory.makeAudioFormat(&inSourceFormat),
            let outputFormat = settings.format.makeAudioFormat(inSourceFormat) else {
            return nil
        }
        if logger.isEnabledFor(level: .info) {
            logger.info("inputFormat:", inputFormat, ",outputFormat:", outputFormat)
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

extension AudioCodec: Codec {
    // MARK: Codec
    typealias Buffer = AVAudioBuffer

    var inputBuffer: AVAudioBuffer {
        return inputBuffers[cursor]
    }

    var outputBuffer: AVAudioBuffer {
        guard let outputFormat = audioConverter?.outputFormat else {
            return .init()
        }
        if outputBuffers.isEmpty {
            return settings.format.makeAudioBuffer(outputFormat) ?? .init()
        }
        return outputBuffers.removeFirst()
    }

    func releaseOutputBuffer(_ buffer: AVAudioBuffer) {
        outputBuffers.append(buffer)
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
            self.isRunning.mutate { $0 = false }
        }
    }
}
