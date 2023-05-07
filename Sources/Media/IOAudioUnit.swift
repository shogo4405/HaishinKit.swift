import AVFoundation

#if canImport(SwiftPMSupport)
import SwiftPMSupport
#endif

final class IOAudioUnit: NSObject, IOUnit {
    lazy var codec: AudioCodec = {
        var codec = AudioCodec()
        codec.lockQueue = lockQueue
        return codec
    }()
    let lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.AudioIOComponent.lock")
    var soundTransform: SoundTransform = .init() {
        didSet {
            soundTransform.apply(mixer?.mediaLink.playerNode)
        }
    }
    var muted = false
    weak var mixer: IOMixer?
    #if os(iOS) || os(macOS)
    private(set) var capture: IOAudioCaptureUnit = .init()
    #endif
    private var inSourceFormat: AudioStreamBasicDescription? {
        didSet {
            guard inSourceFormat != oldValue else {
                return
            }
            presentationTimeStamp = .invalid
            codec.inSourceFormat = inSourceFormat
        }
    }
    private var presentationTimeStamp: CMTime = .invalid

    #if os(iOS) || os(macOS)
    func attachAudio(_ device: AVCaptureDevice?, automaticallyConfiguresApplicationAudioSession: Bool) throws {
        guard let mixer else {
            return
        }
        mixer.session.beginConfiguration()
        defer {
            mixer.session.commitConfiguration()
        }
        guard let device else {
            try capture.attachDevice(nil, audioUnit: self)
            return
        }
        try capture.attachDevice(device, audioUnit: self)
        #if os(iOS)
        mixer.session.automaticallyConfiguresApplicationAudioSession = automaticallyConfiguresApplicationAudioSession
        #endif
    }
    #endif

    func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard CMSampleBufferDataIsReady(sampleBuffer), let sampleBuffer = sampleBuffer.muted(muted) else {
            return
        }
        inSourceFormat = sampleBuffer.formatDescription?.streamBasicDescription?.pointee
        if isFragmented(sampleBuffer), let sampleBuffer = makeSampleBuffer(sampleBuffer) {
            appendSampleBuffer(sampleBuffer)
        }
        mixer?.recorder.appendSampleBuffer(sampleBuffer, mediaType: .audio)
        codec.appendSampleBuffer(sampleBuffer)
        presentationTimeStamp = CMTimeAdd(presentationTimeStamp, CMTime(value: CMTimeValue(sampleBuffer.numSamples), timescale: presentationTimeStamp.timescale))
    }

    func registerEffect(_ effect: AudioEffect) -> Bool {
        codec.effects.insert(effect).inserted
    }

    func unregisterEffect(_ effect: AudioEffect) -> Bool {
        codec.effects.remove(effect) != nil
    }

    private func isFragmented(_ sampleBuffer: CMSampleBuffer) -> Bool {
        if presentationTimeStamp == .invalid {
            presentationTimeStamp = sampleBuffer.presentationTimeStamp
            return false
        }
        return presentationTimeStamp != sampleBuffer.presentationTimeStamp
    }

    private func makeSampleBuffer(_ buffer: CMSampleBuffer) -> CMSampleBuffer? {
        let numSamples = min(Int(buffer.presentationTimeStamp.value - presentationTimeStamp.value), Int(presentationTimeStamp.timescale))
        guard 0 < numSamples else {
            return nil
        }
        var status: OSStatus = noErr
        var sampleBuffer: CMSampleBuffer?
        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: presentationTimeStamp.timescale),
            presentationTimeStamp: presentationTimeStamp,
            decodeTimeStamp: .invalid
        )
        status = CMSampleBufferCreate(
            allocator: kCFAllocatorDefault,
            dataBuffer: nil,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: buffer.formatDescription,
            sampleCount: numSamples,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 0,
            sampleSizeArray: nil,
            sampleBufferOut: &sampleBuffer
        )
        guard
            let sampleBuffer = sampleBuffer,
            let formatDescription = sampleBuffer.formatDescription, status == noErr else {
            return nil
        }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: AVAudioFormat(cmAudioFormatDescription: formatDescription), frameCapacity: AVAudioFrameCount(numSamples)) else {
            return nil
        }
        buffer.frameLength = buffer.frameCapacity
        status = CMSampleBufferSetDataBufferFromAudioBufferList(
            sampleBuffer,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: 0,
            bufferList: buffer.audioBufferList
        )
        guard status == noErr else {
            return nil
        }
        return sampleBuffer
    }
}

extension IOAudioUnit: IOUnitEncoding {
    // MARK: IOUnitEncoding
    func startEncoding(_ delegate: any AVCodecDelegate) {
        codec.delegate = delegate
        codec.startRunning()
    }

    func stopEncoding() {
        codec.stopRunning()
        codec.delegate = nil
        inSourceFormat = nil
    }
}

extension IOAudioUnit: IOUnitDecoding {
    // MARK: IOUnitDecoding
    func startDecoding() {
        if let playerNode = mixer?.mediaLink.playerNode {
            mixer?.audioEngine?.attach(playerNode)
        }
        codec.delegate = self
        codec.startRunning()
    }

    func stopDecoding() {
        if let playerNode = mixer?.mediaLink.playerNode {
            mixer?.audioEngine?.detach(playerNode)
        }
        codec.stopRunning()
        codec.delegate = nil
        inSourceFormat = nil
    }
}

#if os(iOS) || os(macOS)
extension IOAudioUnit: AVCaptureAudioDataOutputSampleBufferDelegate {
    // MARK: AVCaptureAudioDataOutputSampleBufferDelegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard mixer?.useSampleBuffer(sampleBuffer: sampleBuffer, mediaType: AVMediaType.audio) == true else {
            return
        }
        appendSampleBuffer(sampleBuffer)
    }
}
#endif

extension IOAudioUnit: AudioCodecDelegate {
    // MARK: AudioConverterDelegate
    func audioCodec(_ codec: AudioCodec, errorOccurred error: AudioCodec.Error) {
    }

    func audioCodec(_ codec: AudioCodec, didOutput audioFormat: AVAudioFormat) {
        do {
            mixer?.audioFormat = audioFormat
            if let audioEngine = mixer?.audioEngine, audioEngine.isRunning == false {
                try audioEngine.start()
            }
        } catch {
            logger.error(error)
        }
    }

    func audioCodec(_ codec: AudioCodec, didOutput audioBuffer: AVAudioBuffer, presentationTimeStamp: CMTime) {
        guard let audioBuffer = audioBuffer as? AVAudioPCMBuffer else {
            return
        }
        if let mixer = mixer {
            mixer.delegate?.mixer(mixer, didOutput: audioBuffer, presentationTimeStamp: presentationTimeStamp)
        }
        mixer?.mediaLink.enqueueAudio(audioBuffer)
    }
}
