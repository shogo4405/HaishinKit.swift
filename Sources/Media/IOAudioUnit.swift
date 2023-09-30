import AVFoundation

#if canImport(SwiftPMSupport)
import SwiftPMSupport
#endif

final class IOAudioUnit: NSObject, IOUnit {
    typealias FormatDescription = CMAudioFormatDescription

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
    var inputBuffer: AVAudioBuffer? {
        return codec.inputBuffer
    }
    private(set) var presentationTimeStamp: CMTime = .invalid
    private lazy var codec: AudioCodec = {
        var codec = AudioCodec()
        codec.lockQueue = lockQueue
        return codec
    }()
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
    #elseif os(iOS) || os(macOS)
    private(set) var capture: IOAudioCaptureUnit = .init()
    #endif

    #if os(iOS) || os(macOS) || os(tvOS)
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
    #endif

    func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        switch sampleBuffer.formatDescription?.audioStreamBasicDescription?.mFormatID {
        case kAudioFormatLinearPCM:
            resampler.appendSampleBuffer(sampleBuffer.muted(muted))
        default:
            codec.appendSampleBuffer(sampleBuffer)
        }
    }

    func appendAudioBuffer(_ audioBuffer: AVAudioBuffer, presentationTimeStamp: CMTime) {
        codec.appendAudioBuffer(audioBuffer, presentationTimeStamp: presentationTimeStamp)
    }

    func setAudioStreamBasicDescription(_ audioStreamBasicDescription: AudioStreamBasicDescription?) {
        guard var audioStreamBasicDescription else {
            return
        }
        let status = CMAudioFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            asbd: &audioStreamBasicDescription,
            layoutSize: 0,
            layout: nil,
            magicCookieSize: 0,
            magicCookie: nil,
            extensions: nil,
            formatDescriptionOut: &inputFormat
        )
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
        codec.settings.format = .pcm
        if let playerNode = mixer?.mediaLink.playerNode {
            mixer?.audioEngine?.attach(playerNode)
        }
        codec.delegate = mixer
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

#if os(iOS) || os(tvOS) || os(macOS)
@available(tvOS 17.0, *)
extension IOAudioUnit: AVCaptureAudioDataOutputSampleBufferDelegate {
    // MARK: AVCaptureAudioDataOutputSampleBufferDelegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        resampler.appendSampleBuffer(sampleBuffer.muted(muted))
    }
}
#endif

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
        self.presentationTimeStamp = presentationTimeStamp
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
