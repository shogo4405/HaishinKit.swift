import AVFoundation

#if canImport(SwiftPMSupport)
import SwiftPMSupport
#endif

/// The IOAudioUnit  error domain codes.
public enum IOAudioUnitError: Swift.Error {
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

final class IOAudioUnit: NSObject, IOUnit {
    typealias FormatDescription = AVAudioFormat

    let lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.IOAudioUnit.lock")
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
            audioMixer.settings = settings.makeAudioMixerSettings()
        }
    }
    var isRunning: Atomic<Bool> {
        return codec.isRunning
    }
    private(set) var inputFormat: FormatDescription?
    var outputFormat: FormatDescription? {
        return codec.outputFormat
    }
    private lazy var codec: AudioCodec<IOMixer> = {
        var codec = AudioCodec<IOMixer>(lockQueue: lockQueue)
        codec.delegate = mixer
        return codec
    }()
    private lazy var audioMixer: any IOAudioMixerConvertible = {
        if FeatureUtil.isEnabled(feature: .multiTrackAudioMixing) {
            var audioMixer = IOAudioMixerConvertibleByMultiTrack()
            audioMixer.delegate = self
            return audioMixer
        } else {
            var audioMixer = IOAudioMixerConvertibleBySingleTrack()
            audioMixer.delegate = self
            return audioMixer
        }
    }()
    private var monitor: IOAudioMonitor = .init()
    #if os(tvOS)
    private var _capture: Any?
    @available(tvOS 17.0, *)
    private var capture: IOAudioCaptureUnit {
        if _capture == nil {
            _capture = IOAudioCaptureUnit()
        }
        return _capture as! IOAudioCaptureUnit
    }
    #elseif os(iOS) || os(macOS)
    private var capture: IOAudioCaptureUnit = .init()
    #endif

    #if os(iOS) || os(macOS) || os(tvOS)
    @available(tvOS 17.0, *)
    func attachAudio(_ device: AVCaptureDevice?, automaticallyConfiguresApplicationAudioSession: Bool) throws {
        try mixer?.session.configuration { session in
            guard let device else {
                try capture.attachDevice(nil, audioUnit: self)
                inputFormat = nil
                return
            }
            try capture.attachDevice(device, audioUnit: self)
            #if os(iOS)
            session.automaticallyConfiguresApplicationAudioSession = automaticallyConfiguresApplicationAudioSession
            #endif
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
}

#if os(iOS) || os(tvOS) || os(macOS)
@available(tvOS 17.0, *)
extension IOAudioUnit: AVCaptureAudioDataOutputSampleBufferDelegate {
    // MARK: AVCaptureAudioDataOutputSampleBufferDelegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        audioMixer.append(sampleBuffer.muted(muted), track: 0)
    }
}
#endif

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
        inputFormat = audioMixer.inputFormat
        codec.inputFormat = audioFormat
        monitor.inputFormat = audioFormat
    }

    func audioMixer(_ audioMixer: any IOAudioMixerConvertible, didOutput audioBuffer: AVAudioPCMBuffer, when: AVAudioTime) {
        mixer?.audioUnit(self, didOutput: audioBuffer, when: when)
        monitor.append(audioBuffer, when: when)
        codec.append(audioBuffer, when: when)
    }
}
