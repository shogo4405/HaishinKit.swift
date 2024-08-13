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
        let (stream, continutation) = AsyncStream<(AVAudioPCMBuffer, AVAudioTime)>.makeStream()
        self.continutation = continutation
        return stream
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
    private var _captures: [UInt8: Any] = [:]
    @available(tvOS 17.0, *)
    var captures: [UInt8: AudioCaptureUnit] {
        return _captures as! [UInt8: AudioCaptureUnit]
    }
    #elseif os(iOS) || os(macOS)
    var captures: [UInt8: AudioDeviceUnit] = [:]
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
            for capture in captures.values where capture.device == device {
                try? capture.attachDevice(nil, session: session, audioUnit: self)
            }
            guard let capture = self.capture(for: track) else {
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
    private func capture(for track: UInt8) -> AudioDeviceUnit? {
        #if os(tvOS)
        if _captures[track] == nil {
            _captures[track] = .init(track)
        }
        return _captures[track] as? AudioDeviceUnit
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
        continutation?.yield((audioBuffer, when))
        monitor.append(audioBuffer, when: when)
    }
}
