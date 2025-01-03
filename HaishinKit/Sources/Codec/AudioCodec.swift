import AVFoundation

// MARK: -
/**
 * The AudioCodec translate audio data to another format.
 * - seealso: https://developer.apple.com/library/ios/technotes/tn2236/_index.html
 */
final class AudioCodec {
    static let frameCamacity: UInt32 = 1024

    /// Specifies the settings for audio codec.
    var settings: AudioCodecSettings = .default {
        didSet {
            settings.apply(audioConverter, oldValue: oldValue)
        }
    }

    var outputFormat: AVAudioFormat? {
        return audioConverter?.outputFormat
    }

    var outputStream: AsyncStream<(AVAudioBuffer, AVAudioTime)> {
        AsyncStream { continuation in
            self.continuation = continuation
        }
    }

    /// This instance is running to process(true) or not(false).
    private(set) var isRunning = false
    private(set) var inputFormat: AVAudioFormat? {
        didSet {
            guard inputFormat != oldValue else {
                return
            }
            cursor = 0
            inputBuffers.removeAll()
            outputBuffers.removeAll()
            audioConverter = makeAudioConverter()
            for _ in 0..<settings.format.inputBufferCounts {
                if let inputBuffer = makeInputBuffer() {
                    inputBuffers.append(inputBuffer)
                }
            }
        }
    }
    private var cursor: Int = 0
    private var inputBuffers: [AVAudioBuffer] = []
    private var continuation: AsyncStream<(AVAudioBuffer, AVAudioTime)>.Continuation? {
        didSet {
            oldValue?.finish()
        }
    }
    private var outputBuffers: [AVAudioBuffer] = []
    private var audioConverter: AVAudioConverter?

    func append(_ sampleBuffer: CMSampleBuffer) {
        guard isRunning else {
            return
        }
        switch settings.format {
        case .pcm:
            if let formatDescription = sampleBuffer.formatDescription, inputFormat?.formatDescription != formatDescription {
                inputFormat = AVAudioFormat(cmAudioFormatDescription: formatDescription)
            }
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
                    append(buffer, when: presentationTimeStamp.makeAudioTime())
                    presentationTimeStamp = CMTimeAdd(presentationTimeStamp, CMTime(value: CMTimeValue(1024), timescale: sampleBuffer.presentationTimeStamp.timescale))
                    offset += sampleSize
                }
            }
        default:
            break
        }
    }

    func append(_ audioBuffer: AVAudioBuffer, when: AVAudioTime) {
        inputFormat = audioBuffer.format
        guard let audioConverter, isRunning else {
            return
        }
        var error: NSError?
        let outputBuffer = self.outputBuffer
        let outputStatus = audioConverter.convert(to: outputBuffer, error: &error) { _, inputStatus in
            switch self.inputBuffer {
            case let inputBuffer as AVAudioCompressedBuffer:
                inputBuffer.copy(audioBuffer)
            case let inputBuffer as AVAudioPCMBuffer:
                if !inputBuffer.copy(audioBuffer) {
                    inputBuffer.muted(true)
                }
            default:
                break
            }
            inputStatus.pointee = .haveData
            return self.inputBuffer
        }
        switch outputStatus {
        case .haveData:
            continuation?.yield((outputBuffer, when))
        case .error:
            break
        default:
            break
        }
        cursor += 1
        if cursor == inputBuffers.count {
            cursor = 0
        }
    }

    private func makeInputBuffer() -> AVAudioBuffer? {
        guard let inputFormat else {
            return nil
        }
        switch inputFormat.formatDescription.mediaSubType {
        case .linearPCM:
            let buffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: Self.frameCamacity)
            buffer?.frameLength = Self.frameCamacity
            return buffer
        default:
            return AVAudioCompressedBuffer(format: inputFormat, packetCapacity: 1, maximumPacketSize: 1024)
        }
    }

    private func makeAudioConverter() -> AVAudioConverter? {
        guard
            let inputFormat,
            let outputFormat = settings.format.makeOutputAudioFormat(inputFormat) else {
            return nil
        }
        if logger.isEnabledFor(level: .info) {
            logger.info("inputFormat:", inputFormat, ",outputFormat:", outputFormat)
        }
        let converter = AVAudioConverter(from: inputFormat, to: outputFormat)
        settings.apply(converter, oldValue: nil)
        return converter
    }
}

extension AudioCodec: Codec {
    // MARK: Codec
    typealias Buffer = AVAudioBuffer

    var outputBuffer: AVAudioBuffer {
        guard let outputFormat = audioConverter?.outputFormat else {
            return .init()
        }
        if outputBuffers.isEmpty {
            for _ in 0..<settings.format.outputBufferCounts {
                outputBuffers.append(settings.format.makeAudioBuffer(outputFormat) ?? .init())
            }
        }
        return outputBuffers.removeFirst()
    }

    func releaseOutputBuffer(_ buffer: AVAudioBuffer) {
        outputBuffers.append(buffer)
    }

    private var inputBuffer: AVAudioBuffer {
        return inputBuffers[cursor]
    }
}

extension AudioCodec: Runner {
    // MARK: Running
    func startRunning() {
        guard !isRunning else {
            return
        }
        audioConverter?.reset()
        isRunning = true
    }

    func stopRunning() {
        guard isRunning else {
            return
        }
        isRunning = false
        continuation = nil
    }
}
