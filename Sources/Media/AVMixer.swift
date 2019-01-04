import AVFoundation

#if os(iOS) || os(macOS)
    extension AVCaptureSession.Preset {
        static var `default`: AVCaptureSession.Preset = .medium
    }
#endif

public final class AVMixer: NSObject {

    static let supportedSettingsKeys: [String] = [
        "fps",
        "sessionPreset",
        "continuousAutofocus",
        "continuousExposure"
    ]

    static let defaultFPS: Float64 = 30
    static let defaultVideoSettings: [NSString: AnyObject] = [
        kCVPixelBufferPixelFormatTypeKey: NSNumber(value: kCVPixelFormatType_32BGRA)
    ]
#if os(iOS) || os(macOS)

    @objc var fps: Float64 {
        get { return videoIO.fps }
        set { videoIO.fps = newValue }
    }

    @objc var continuousExposure: Bool {
        get { return videoIO.continuousExposure }
        set { videoIO.continuousExposure = newValue }
    }

    @objc var continuousAutofocus: Bool {
        get { return videoIO.continuousAutofocus }
        set { videoIO.continuousAutofocus = newValue }
    }

    @objc var sessionPreset: AVCaptureSession.Preset = .default {
        didSet {
            guard sessionPreset != oldValue else {
                return
            }
            session.beginConfiguration()
            session.sessionPreset = sessionPreset
            session.commitConfiguration()
        }
    }

    private var _session: AVCaptureSession?
    public var session: AVCaptureSession {
        get {
            if _session == nil {
                _session = AVCaptureSession()
                _session!.sessionPreset = .default
            }
            return _session!
        }
        set {
            _session = newValue
        }
    }
#endif
    public private(set) lazy var recorder = AVMixerRecorder()

    deinit {
        dispose()
    }

    private(set) lazy var audioIO: AudioIOComponent = {
       AudioIOComponent(mixer: self)
    }()

    private(set) lazy var videoIO: VideoIOComponent = {
       VideoIOComponent(mixer: self)
    }()

    public func dispose() {
#if os(iOS) || os(macOS)
        if session.isRunning {
            session.stopRunning()
        }
#endif
        audioIO.dispose()
        videoIO.dispose()
    }
}

extension AVMixer {
    public final func startEncoding(delegate: Any) {
        videoIO.encoder.delegate = delegate as? VideoEncoderDelegate
        videoIO.encoder.startRunning()
        audioIO.encoder.delegate = delegate as? AudioConverterDelegate
        audioIO.encoder.startRunning()
    }

    public final func stopEncoding() {
        videoIO.encoder.delegate = nil
        videoIO.encoder.stopRunning()
        audioIO.encoder.delegate = nil
        audioIO.encoder.stopRunning()
    }
}

extension AVMixer {
    public final func startPlaying(_ audioEngine: AVAudioEngine?) {
        audioIO.audioEngine = audioEngine
        audioIO.encoder.delegate = audioIO
        videoIO.queue.startRunning()
    }

    public final func stopPlaying() {
        audioIO.audioEngine = nil
        audioIO.encoder.delegate = nil
        videoIO.queue.stopRunning()
    }
}

#if os(iOS) || os(macOS)
extension AVMixer: Running {
    // MARK: Running
    public var isRunning: Bool {
        return session.isRunning
    }

    public final func startRunning() {
        guard !isRunning else {
            return
        }
        DispatchQueue.global(qos: .userInteractive).async {
            self.session.startRunning()
        }
    }

    public final func stopRunning() {
        guard isRunning else {
            return
        }
        session.stopRunning()
    }
}
#else
extension AVMixer: Running {
    // MARK: Running
    public var isRunning: Bool {
        return false
    }

    public final func startRunning() {
    }

    public final func stopRunning() {
    }
}
#endif
