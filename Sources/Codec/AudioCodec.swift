import AVFoundation

/**
 * The interface a AudioCodec uses to inform its delegate.
 */
public protocol AudioCodecDelegate: AnyObject {
    /// Tells the receiver to set a formatDescription.
    func audioCodec(_ codec: AudioCodec, didSet outputFormat: AVAudioFormat)
    /// Tells the receiver to output a encoded or decoded sampleBuffer.
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
        case faildToConvert(error: NSError)
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
            audioBuffer = .init(&inSourceFormat)
            audioConverter = makeAudioConvter(&inSourceFormat)
        }
    }
    private var audioConverter: AVAudioConverter?
    private var audioBuffer: AudioCodecBuffer?

    /// Append a CMSampleBuffer.
    public func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer, offset: Int = 0) {
        guard CMSampleBufferDataIsReady(sampleBuffer), isRunning.value, let audioBuffer, let audioConverter, let buffer = makeOutputBuffer()  else {
            return
        }
        let numSamples = audioBuffer.appendSampleBuffer(sampleBuffer, offset: offset)
        if audioBuffer.isReady {
            for effect in effects {
                effect.execute(audioBuffer.current, presentationTimeStamp: audioBuffer.presentationTimeStamp)
            }
            var error: NSError?
            audioConverter.convert(to: buffer, error: &error) { _, status in
                status.pointee = .haveData
                return audioBuffer.current
            }
            if let error {
                delegate?.audioCodec(self, errorOccurred: .faildToConvert(error: error))
            } else {
                delegate?.audioCodec(self, didOutput: buffer, presentationTimeStamp: audioBuffer.presentationTimeStamp)
            }
            audioBuffer.next()
        }
        if offset + numSamples < sampleBuffer.numSamples {
            appendSampleBuffer(sampleBuffer, offset: offset + numSamples)
        }
    }

    func appendAudioBuffer(_ audioBuffer: AVAudioBuffer, presentationTimeStamp: CMTime) {
        guard isRunning.value, let audioConverter, let buffer = makeOutputBuffer() else {
            return
        }
        var error: NSError?
        audioConverter.convert(to: buffer, error: &error) { _, status in
            status.pointee = .haveData
            return audioBuffer
        }
        if let error {
            delegate?.audioCodec(self, errorOccurred: .faildToConvert(error: error))
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

    private func makeOutputBuffer() -> AVAudioBuffer? {
        guard let outputFormat = audioConverter?.outputFormat else {
            return nil
        }
        return destination.makeAudioBuffer(outputFormat)
    }

    private func makeAudioConvter(_ inSourceFormat: inout AudioStreamBasicDescription) -> AVAudioConverter? {
        guard
            let inputFormat = AVAudioFormat(streamDescription: &inSourceFormat),
            let outputFormat = destination.makeAudioFormat(inSourceFormat) else {
            return nil
        }
        defer {
            delegate?.audioCodec(self, didSet: outputFormat)
        }
        let converter = AVAudioConverter(from: inputFormat, to: outputFormat)
        settings.apply(converter, oldValue: nil)
        return converter
    }
}

extension AudioCodec: Running {
    // MARK: Running
    public func startRunning() {
        lockQueue.async {
            self.isRunning.mutate { $0 = true }
        }
    }

    public func stopRunning() {
        lockQueue.async {
            self.inSourceFormat = nil
            self.audioConverter = nil
            self.audioBuffer = nil
            self.isRunning.mutate { $0 = false }
        }
    }
}
