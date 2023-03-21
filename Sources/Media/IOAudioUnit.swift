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

    func registerEffect(_ effect: AudioEffect) -> Bool {
        codec.effects.insert(effect).inserted
    }

    func unregisterEffect(_ effect: AudioEffect) -> Bool {
        codec.effects.remove(effect) != nil
    }

    func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard let sampleBuffer = sampleBuffer.muted(muted) else {
            return
        }
        mixer?.recorder.appendSampleBuffer(sampleBuffer, mediaType: .audio)
        codec.inSourceFormat = sampleBuffer.formatDescription?.streamBasicDescription?.pointee
        codec.appendSampleBuffer(sampleBuffer)
    }
}

extension IOAudioUnit: IOUnitEncoding {
    // MARK: IOUnitEncoding
    func startEncoding(_ delegate: AVCodecDelegate) {
        codec.delegate = delegate
        codec.startRunning()
    }

    func stopEncoding() {
        codec.stopRunning()
        codec.delegate = nil
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
