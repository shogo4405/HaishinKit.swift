import AVFoundation

#if canImport(SwiftPMSupport)
import SwiftPMSupport
#endif

/// The IOAudioUnit  error domain codes.
public enum IOAudioUnitError: Swift.Error {
    /// The IOAudioUnit failed to attach device.
    case failedToAttach(error: (any Error)?)
    /// The IOAudioUnit  failed to create the AVAudioConverter.
    case failedToCreate(from: AVAudioFormat?, to: AVAudioFormat?)
    /// The IOAudioUnit  faild to convert the an audio buffer.
    case failedToConvert(error: NSError)
    /// The IOAudioUnit  failed to mix the audio buffers.
    case failedToMix(error: any Error)
}

protocol IOAudioUnitDelegate: AnyObject {
    func audioUnit(_ audioUnit: IOAudioUnit, errorOccurred error: IOAudioUnitError)
    func audioUnit(_ audioUnit: IOAudioUnit, didOutput audioBuffer: AVAudioPCMBuffer, when: AVAudioTime)
}

final class IOAudioUnit: IOUnit {
    let lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.IOAudioUnit.lock")
    weak var mixer: IOMixer?

    var muted = false
    var isMonitoringEnabled = false {
        didSet {
            if isMonitoringEnabled {
                monitor.startRunning()
            } else {
                monitor.stopRunning()
            }
        }
    }
    var settings: AudioCodecSettings {
        get {
            codec.settings
        }
        set {
            codec.settings = newValue
        }
    }
    var mixerSettings: IOAudioMixerSettings {
        get {
            audioMixer.settings
        }
        set {
            audioMixer.settings = newValue
        }
    }
    var isRunning: Atomic<Bool> {
        return codec.isRunning
    }
    private(set) var inputFormat: AVAudioFormat?
    var outputFormat: AVAudioFormat? {
        return codec.outputFormat
    }
    private lazy var codec: AudioCodec<IOMixer> = {
        var codec = AudioCodec<IOMixer>(lockQueue: lockQueue)
        codec.delegate = mixer
        return codec
    }()
    private lazy var audioMixer: any IOAudioMixerConvertible = {
        if FeatureUtil.isEnabled(for: .multiTrackAudioMixing) {
            var audioMixer = IOAudioMixerByMultiTrack()
            audioMixer.delegate = self
            return audioMixer
        } else {
            var audioMixer = IOAudioMixerBySingleTrack()
            audioMixer.delegate = self
            return audioMixer
        }
    }()
    private var monitor: IOAudioMonitor = .init()
    #if os(tvOS)
    private var _captures: [UInt8: Any] = [:]
    @available(tvOS 17.0, *)
    var captures: [UInt8: IOAudioCaptureUnit] {
        return _captures as! [UInt8: IOAudioCaptureUnit]
    }
    #elseif os(iOS) || os(macOS) || os(visionOS)
    var captures: [UInt8: IOAudioCaptureUnit] = [:]
    #endif

    #if os(iOS) || os(macOS) || os(tvOS)
    @available(tvOS 17.0, *)
    func attachAudio(_ device: AVCaptureDevice?, track: UInt8, configuration: (_ capture: IOAudioCaptureUnit?) -> Void) throws {
        try mixer?.session.configuration { _ in
            mixer?.session.detachCapture(captures[track])
            guard let device else {
                try captures[track]?.attachDevice(nil)
                return
            }
            let capture = capture(for: track)
            try capture?.attachDevice(device)
            configuration(capture)
            capture?.setSampleBufferDelegate(self)
            mixer?.session.attachCapture(capture)
        }
    }
    #endif

    func append(_ sampleBuffer: CMSampleBuffer, track: UInt8 = 0) {
        switch sampleBuffer.formatDescription?.audioStreamBasicDescription?.mFormatID {
        case kAudioFormatLinearPCM:
            audioMixer.append(sampleBuffer, track: track)
        default:
            if codec.inputFormat?.formatDescription != sampleBuffer.formatDescription {
                if var asbd = sampleBuffer.formatDescription?.audioStreamBasicDescription {
                    codec.inputFormat = AVAudioFormat.init(streamDescription: &asbd)
                }
            }
            codec.append(sampleBuffer)
        }
    }

    func append(_ audioBuffer: AVAudioBuffer, when: AVAudioTime, track: UInt8 = 0) {
        switch audioBuffer {
        case let audioBuffer as AVAudioPCMBuffer:
            audioMixer.append(audioBuffer, when: when, track: track)
        case let audioBuffer as AVAudioCompressedBuffer:
            codec.append(audioBuffer, when: when)
        default:
            break
        }
    }

    @available(tvOS 17.0, *)
    func makeDataOutput(_ track: UInt8) -> IOAudioCaptureUnitDataOutput {
        return .init(track: track, audioMixer: audioMixer)
    }

    @available(tvOS 17.0, *)
    func capture(for track: UInt8) -> IOAudioCaptureUnit? {
        #if os(tvOS)
        if _captures[track] == nil {
            _captures[track] = .init(track)
        }
        return _captures[track] as? IOAudioCaptureUnit
        #else
        if captures[track] == nil {
            captures[track] = .init(track)
        }
        return captures[track]
        #endif
    }
}

extension IOAudioUnit: Running {
    // MARK: Running
    func startRunning() {
        codec.startRunning()
    }

    func stopRunning() {
        codec.stopRunning()
    }
}

extension IOAudioUnit: IOAudioMixerDelegate {
    // MARK: IOAudioMixerDelegate
    func audioMixer(_ audioMixer: any IOAudioMixerConvertible, errorOccurred error: IOAudioUnitError) {
        mixer?.audioUnit(self, errorOccurred: error)
    }

    func audioMixer(_ audioMixer: any IOAudioMixerConvertible, didOutput audioFormat: AVAudioFormat) {
        codec.inputFormat = audioFormat
        monitor.inputFormat = audioFormat
    }

    func audioMixer(_ audioMixer: any IOAudioMixerConvertible, didOutput audioBuffer: AVAudioPCMBuffer, when: AVAudioTime) {
        if muted {
            audioBuffer.muted()
        }
        mixer?.audioUnit(self, didOutput: audioBuffer, when: when)
        monitor.append(audioBuffer, when: when)
        codec.append(audioBuffer, when: when)
    }
}
