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

    static func makeAudioFormat(_ inSourceFormat: inout AudioStreamBasicDescription) -> AVAudioFormat? {
        if inSourceFormat.mFormatID == kAudioFormatLinearPCM && kLinearPCMFormatFlagIsBigEndian == (inSourceFormat.mFormatFlags & kLinearPCMFormatFlagIsBigEndian) {
            // ReplayKit audioApp.
            guard inSourceFormat.mBitsPerChannel == 16 else {
                return nil
            }
            if let layout = Self.makeChannelLayout(inSourceFormat.mChannelsPerFrame) {
                return .init(commonFormat: .pcmFormatInt16, sampleRate: inSourceFormat.mSampleRate, interleaved: true, channelLayout: layout)
            }
            return AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: inSourceFormat.mSampleRate, channels: inSourceFormat.mChannelsPerFrame, interleaved: true)
        }
        if let layout = Self.makeChannelLayout(inSourceFormat.mChannelsPerFrame) {
            return .init(streamDescription: &inSourceFormat, channelLayout: layout)
        }
        return .init(streamDescription: &inSourceFormat)
    }

    static func makeChannelLayout(_ numberOfChannels: UInt32) -> AVAudioChannelLayout? {
        guard numberOfChannels > 2 else {
            return nil
        }
        return AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_DiscreteInOrder | numberOfChannels)
    }

    /// Creates a channel map for specific input and output format
    static func makeChannelMap(inChannels: Int, outChannels: Int, outputChannelsMap: [Int: Int]) -> [NSNumber] {
        var result = Array(repeating: -1, count: outChannels)
        for inputIndex in 0..<min(inChannels, outChannels) {
            result[inputIndex] = inputIndex
        }
        for currentIndex in 0..<outChannels {
            if let inputIndex = outputChannelsMap[currentIndex], inputIndex < inChannels {
                result[currentIndex] = inputIndex
            }
        }
        return result.map { NSNumber(value: $0) }
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
        guard isRunning.value else {
            return
        }
        switch settings.format {
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
            return settings.format.makeAudioBuffer(outputFormat)
        }
        return outputBuffers.removeFirst()
    }

    private func makeAudioConverter(_ inSourceFormat: inout AudioStreamBasicDescription) -> AVAudioConverter? {
        guard
            let inputFormat = Self.makeAudioFormat(&inSourceFormat),
            let outputFormat = settings.format.makeAudioFormat(inSourceFormat) else {
            return nil
        }
        logger.debug("inputFormat: \(inputFormat)")
        logger.debug("outputFormat: \(outputFormat)")
        let converter = AVAudioConverter(from: inputFormat, to: outputFormat)
        let channelMap = Self.makeChannelMap(inChannels: Int(inputFormat.channelCount), outChannels: Int(outputFormat.channelCount), outputChannelsMap: settings.outputChannelsMap)
        logger.debug("channelMap: \(channelMap)")
        converter?.channelMap = channelMap
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
