import AVFoundation

#if canImport(SwiftPMSupport)
import SwiftPMSupport
#endif

final class IOAudioUnit: NSObject, IOUnit {
    typealias FormatDescription = CMAudioFormatDescription

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
    var isMonitoringEnabled = false {
        didSet {
            if isMonitoringEnabled {
                monitor.startRunning()
            } else {
                monitor.stopRunning()
            }
        }
    }
    var settings: AudioCodecSettings = .default {
        didSet {
            codec.settings = settings
            resampler.settings = settings.makeAudioResamplerSettings()
        }
    }
    var inputFormat: FormatDescription?
    var outputFormat: FormatDescription? {
        return codec.outputFormat?.formatDescription
    }
    private(set) var presentationTimeStamp: CMTime = .invalid
    private var effects: Set<AudioEffect> = []
    private lazy var resampler: IOAudioResampler<IOAudioUnit> = {
        var resampler = IOAudioResampler<IOAudioUnit>()
        resampler.delegate = self
        return resampler
    }()
    private var monitor: IOAudioMonitor = .init()
    #if os(tvOS)
    private var _capture: Any?
    @available(tvOS 17.0, *)
    var capture: IOAudioCaptureUnit {
        if _capture == nil {
            _capture = IOAudioCaptureUnit()
        }
        return _capture as! IOAudioCaptureUnit
    }
    #else
    private(set) var capture: IOAudioCaptureUnit = .init()
    #endif

    @available(tvOS 17.0, *)
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
            presentationTimeStamp = .invalid
            inputFormat = nil
            return
        }
        try capture.attachDevice(device, audioUnit: self)
        #if os(iOS)
        mixer.session.automaticallyConfiguresApplicationAudioSession = automaticallyConfiguresApplicationAudioSession
        #endif
    }

    func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        presentationTimeStamp = sampleBuffer.presentationTimeStamp
        resampler.appendSampleBuffer(sampleBuffer.muted(muted))
    }

    func registerEffect(_ effect: AudioEffect) -> Bool {
        effects.insert(effect).inserted
    }

    func unregisterEffect(_ effect: AudioEffect) -> Bool {
        effects.remove(effect) != nil
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

@available(tvOS 17.0, *)
extension IOAudioUnit: AVCaptureAudioDataOutputSampleBufferDelegate {
    // MARK: AVCaptureAudioDataOutputSampleBufferDelegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        appendSampleBuffer(sampleBuffer)
    }
}

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
        if let mixer {
            mixer.delegate?.mixer(mixer, didOutput: audioBuffer, presentationTimeStamp: presentationTimeStamp)
        }
        mixer?.mediaLink.enqueueAudio(audioBuffer)
    }
}

extension IOAudioUnit: IOAudioResamplerDelegate {
    // MARK: IOAudioResamplerDelegate
    func resampler(_ resampler: IOAudioResampler<IOAudioUnit>, errorOccurred error: AudioCodec.Error) {
    }

    func resampler(_ resampler: IOAudioResampler<IOAudioUnit>, didOutput audioFormat: AVAudioFormat) {
        inputFormat = resampler.inputFormat?.formatDescription
        codec.inSourceFormat = audioFormat.formatDescription.audioStreamBasicDescription
        monitor.inSourceFormat = audioFormat.formatDescription.audioStreamBasicDescription
    }

    func resampler(_ resampler: IOAudioResampler<IOAudioUnit>, didOutput audioBuffer: AVAudioPCMBuffer, presentationTimeStamp: CMTime) {
        for effect in effects {
            effect.execute(audioBuffer, presentationTimeStamp: presentationTimeStamp)
        }
        if let mixer {
            mixer.delegate?.mixer(mixer, didOutput: audioBuffer, presentationTimeStamp: presentationTimeStamp)
            if mixer.recorder.isRunning.value, let sampleBuffer = audioBuffer.makeSampleBuffer(presentationTimeStamp) {
                mixer.recorder.appendSampleBuffer(sampleBuffer)
            }
        }
        monitor.appendAudioPCMBuffer(audioBuffer)
        codec.appendAudioBuffer(audioBuffer, presentationTimeStamp: presentationTimeStamp)
    }
}
