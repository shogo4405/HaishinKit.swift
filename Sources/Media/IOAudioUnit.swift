import AVFoundation

#if canImport(SwiftPMSupport)
import SwiftPMSupport
#endif

protocol IOAudioUnitDelegate: AnyObject {
    func audioUnit(_ audioUnit: IOAudioUnit, errorOccurred error: IOMixerAudioError)
    func audioUnit(_ audioUnit: IOAudioUnit, didOutput audioBuffer: AVAudioPCMBuffer, when: AVAudioTime)
}

final class IOAudioUnit: NSObject, IOUnit {
    typealias FormatDescription = AVAudioFormat

    let lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.IOAudioUnit.lock")
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
    private(set) var inputFormat: FormatDescription?
    var outputFormat: FormatDescription? {
        return codec.outputFormat
    }
    var inputBuffer: AVAudioBuffer? {
        return codec.inputBuffer
    }
    private lazy var codec: AudioCodec<IOMixer> = {
        var codec = AudioCodec<IOMixer>(lockQueue: lockQueue)
        codec.delegate = mixer
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
            inputFormat = nil
            return
        }
        try capture.attachDevice(device, audioUnit: self)
        #if os(iOS)
        mixer.session.automaticallyConfiguresApplicationAudioSession = automaticallyConfiguresApplicationAudioSession
        #endif
    }
    #endif

    func append(_ sampleBuffer: CMSampleBuffer) {
        switch sampleBuffer.formatDescription?.audioStreamBasicDescription?.mFormatID {
        case kAudioFormatLinearPCM:
            resampler.append(sampleBuffer.muted(muted))
        default:
            codec.append(sampleBuffer)
        }
    }

    func append(_ audioBuffer: AVAudioBuffer, when: AVAudioTime) {
        switch audioBuffer {
        case let audioBuffer as AVAudioPCMBuffer:
            resampler.append(audioBuffer, when: when)
        case let audioBuffer as AVAudioCompressedBuffer:
            codec.append(audioBuffer, when: when)
        default:
            break
        }
    }

    func setAudioStreamBasicDescription(_ audioStreamBasicDescription: AudioStreamBasicDescription?) {
        guard var audioStreamBasicDescription else {
            return
        }
        let audioFormat = AVAudioFormat(streamDescription: &audioStreamBasicDescription)
        inputFormat = audioFormat
        codec.inputFormat = audioFormat
    }
}

extension IOAudioUnit: IOUnitEncoding {
    // MARK: IOUnitEncoding
    func startEncoding() {
        codec.startRunning()
    }

    func stopEncoding() {
        codec.stopRunning()
    }
}

extension IOAudioUnit: IOUnitDecoding {
    // MARK: IOUnitDecoding
    func startDecoding() {
        codec.settings.format = .pcm
        if let playerNode = mixer?.mediaLink.playerNode {
            mixer?.audioEngine?.attach(playerNode)
        }
        codec.startRunning()
    }

    func stopDecoding() {
        if let playerNode = mixer?.mediaLink.playerNode {
            mixer?.audioEngine?.detach(playerNode)
        }
        codec.stopRunning()
    }
}

#if os(iOS) || os(tvOS) || os(macOS)
@available(tvOS 17.0, *)
extension IOAudioUnit: AVCaptureAudioDataOutputSampleBufferDelegate {
    // MARK: AVCaptureAudioDataOutputSampleBufferDelegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        resampler.append(sampleBuffer.muted(muted))
    }
}
#endif

extension IOAudioUnit: IOAudioResamplerDelegate {
    // MARK: IOAudioResamplerDelegate
    func resampler(_ resampler: IOAudioResampler<IOAudioUnit>, errorOccurred error: IOMixerAudioError) {
        mixer?.audioUnit(self, errorOccurred: error)
    }

    func resampler(_ resampler: IOAudioResampler<IOAudioUnit>, didOutput audioFormat: AVAudioFormat) {
        inputFormat = resampler.inputFormat
        codec.inputFormat = audioFormat
        monitor.inputFormat = audioFormat
    }

    func resampler(_ resampler: IOAudioResampler<IOAudioUnit>, didOutput audioBuffer: AVAudioPCMBuffer, when: AVAudioTime) {
        mixer?.audioUnit(self, didOutput: audioBuffer, when: when)
        monitor.append(audioBuffer, when: when)
        codec.append(audioBuffer, when: when)
    }
}
