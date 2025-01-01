import AVFoundation

final class AudioCaptureUnit: CaptureUnit {
    let lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.AudioCaptureUnit.lock")
    var mixerSettings: AudioMixerSettings {
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
        AsyncStream<(AVAudioPCMBuffer, AVAudioTime)> { continutation in
            self.continutation = continutation
        }
    }
    private lazy var audioMixer: any AudioMixer = {
        if isMultiTrackAudioMixingEnabled {
            var mixer = AudioMixerByMultiTrack()
            mixer.delegate = self
            return mixer
        } else {
            var mixer = AudioMixerBySingleTrack()
            mixer.delegate = self
            return mixer
        }
    }()
    private var monitor: AudioMonitor = .init()

    #if os(tvOS)
    private var _devices: [UInt8: Any] = [:]
    @available(tvOS 17.0, *)
    var devices: [UInt8: AudioDeviceUnit] {
        return _devices as! [UInt8: AudioDeviceUnit]
    }
    #elseif os(iOS) || os(macOS)
    var devices: [UInt8: AudioDeviceUnit] = [:]
    #endif

    private let session: CaptureSession
    private var continutation: AsyncStream<(AVAudioPCMBuffer, AVAudioTime)>.Continuation?

    init(_ session: CaptureSession) {
        self.session = session
    }

    #if os(iOS) || os(macOS) || os(tvOS)
    @available(tvOS 17.0, *)
    func attachAudio(_ track: UInt8, device: AVCaptureDevice?, configuration: AudioDeviceConfigurationBlock?) throws {
        try session.configuration { _ in
            for capture in devices.values where capture.device == device {
                try? capture.attachDevice(nil, session: session, audioUnit: self)
            }
            guard let capture = self.device(for: track) else {
                return
            }
            try? configuration?(capture)
            try capture.attachDevice(device, session: session, audioUnit: self)
        }
    }

    @available(tvOS 17.0, *)
    func makeDataOutput(_ track: UInt8) -> AudioDeviceUnitDataOutput {
        return .init(track: track, audioMixer: audioMixer)
    }

    @available(tvOS 17.0, *)
    private func device(for track: UInt8) -> AudioDeviceUnit? {
        #if os(tvOS)
        if _devices[track] == nil {
            _devices[track] = .init(track)
        }
        return _devices[track] as? AudioDeviceUnit
        #else
        if devices[track] == nil {
            devices[track] = .init(track)
        }
        return devices[track]
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

    func finish() {
        continutation?.finish()
    }
}

extension AudioCaptureUnit: AudioMixerDelegate {
    // MARK: AudioMixerDelegate
    func audioMixer(_ audioMixer: some AudioMixer, track: UInt8, didInput buffer: AVAudioPCMBuffer, when: AVAudioTime) {
    }

    func audioMixer(_ audioMixer: some AudioMixer, errorOccurred error: AudioMixerError) {
    }

    func audioMixer(_ audioMixer: some AudioMixer, didOutput audioFormat: AVAudioFormat) {
        monitor.inputFormat = audioFormat
    }

    func audioMixer(_ audioMixer: some AudioMixer, didOutput audioBuffer: AVAudioPCMBuffer, when: AVAudioTime) {
        if let audioBuffer = audioBuffer.clone() {
            continutation?.yield((audioBuffer, when))
        }
        monitor.append(audioBuffer, when: when)
    }
}
