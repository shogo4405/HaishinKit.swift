@preconcurrency import AVFoundation

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

final class IOAudioUnit: IOUnit {
    let lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.IOAudioUnit.lock")
    var mixerSettings: IOAudioMixerSettings {
        get {
            audioMixer.settings
        }
        set {
            audioMixer.settings = newValue
        }
    }
    var isMonitoringEnabled = false {
        didSet {
            if isMonitoringEnabled {
                monitor.startRunning()
            } else {
                monitor.stopRunning()
            }
        }
    }
    var isMultiTrackAudioMixingEnabled = false
    var inputFormats: [UInt8: AVAudioFormat] {
        return audioMixer.inputFormats
    }
    var output: AsyncStream<(AVAudioPCMBuffer, AVAudioTime)> {
        let (stream, continutation) = AsyncStream<(AVAudioPCMBuffer, AVAudioTime)>.makeStream()
        self.continutation = continutation
        return stream
    }
    private lazy var audioMixer: any IOAudioMixerConvertible = {
        if isMultiTrackAudioMixingEnabled {
            var mixer = IOAudioMixerByMultiTrack()
            mixer.delegate = self
            return mixer
        } else {
            var mixer = IOAudioMixerBySingleTrack()
            mixer.delegate = self
            return mixer
        }
    }()
    private var monitor: IOAudioMonitor = .init()
    #if os(tvOS)
    private var _captures: [UInt8: Any] = [:]
    @available(tvOS 17.0, *)
    var captures: [UInt8: IOAudioCaptureUnit] {
        return _captures as! [UInt8: IOAudioCaptureUnit]
    }
    #elseif os(iOS) || os(macOS)
    var captures: [UInt8: IOAudioCaptureUnit] = [:]
    #endif
    private let session: IOCaptureSession
    private var continutation: AsyncStream<(AVAudioPCMBuffer, AVAudioTime)>.Continuation?

    init(_ session: IOCaptureSession) {
        self.session = session
    }

    #if os(iOS) || os(macOS) || os(tvOS)
    @available(tvOS 17.0, *)
    func attachAudio(_ track: UInt8, device: AVCaptureDevice?, configuration: IOAudioCaptureConfigurationBlock?) throws {
        try session.configuration { _ in
            session.detachCapture(captures[track])
            guard let device else {
                try captures[track]?.attachDevice(nil)
                return
            }
            let capture = capture(for: track)
            try capture?.attachDevice(device)
            configuration?(capture)
            capture?.setSampleBufferDelegate(self)
            session.attachCapture(capture)
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
    #endif

    func append(_ track: UInt8, buffer: CMSampleBuffer) {
        audioMixer.append(track, buffer: buffer)
    }

    func append(_ track: UInt8, buffer: AVAudioBuffer, when: AVAudioTime) {
        switch buffer {
        case let buffer as AVAudioPCMBuffer:
            audioMixer.append(track, buffer: buffer, when: when)
        default:
            break
        }
    }
}

extension IOAudioUnit: IOAudioMixerDelegate {
    // MARK: IOAudioMixerDelegate
    func audioMixer(_ audioMixer: some IOAudioMixerConvertible, track: UInt8, didInput buffer: AVAudioPCMBuffer, when: AVAudioTime) {
    }

    func audioMixer(_ audioMixer: some IOAudioMixerConvertible, errorOccurred error: IOAudioUnitError) {
    }

    func audioMixer(_ audioMixer: some IOAudioMixerConvertible, didOutput audioFormat: AVAudioFormat) {
        monitor.inputFormat = audioFormat
    }

    func audioMixer(_ audioMixer: some IOAudioMixerConvertible, didOutput audioBuffer: AVAudioPCMBuffer, when: AVAudioTime) {
        continutation?.yield((audioBuffer, when))
        monitor.append(audioBuffer, when: when)
    }
}
