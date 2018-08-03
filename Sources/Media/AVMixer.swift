import AVFoundation

#if os(iOS) || os(macOS)
    extension AVCaptureSession.Preset {
        static var `default`: AVCaptureSession.Preset = .medium
    }
#endif

final public class AVMixer: NSObject {

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
       return AudioIOComponent(mixer: self)
    }()

    private(set) lazy var videoIO: VideoIOComponent = {
       return VideoIOComponent(mixer: self)
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
    final func startEncoding(delegate: Any) {
        videoIO.encoder.delegate = delegate as? VideoEncoderDelegate
        videoIO.encoder.startRunning()
        audioIO.encoder.delegate = delegate as? AudioEncoderDelegate
        audioIO.encoder.startRunning()
    }
    final func stopEncoding() {
        videoIO.encoder.delegate = nil
        videoIO.encoder.stopRunning()
        audioIO.encoder.delegate = nil
        audioIO.encoder.stopRunning()
    }
}

extension AVMixer {
    final func startPlaying() {
        audioIO.playback.startRunning()
        videoIO.queue.startRunning()
    }
    final func stopPlaying() {
        audioIO.playback.stopRunning()
        videoIO.queue.stopRunning()
    }
}

#if os(iOS) || os(macOS)
extension AVMixer: Running {
    // MARK: Running
    var running: Bool {
        return session.isRunning
    }

    final func startRunning() {
        guard !running else {
            return
        }
        DispatchQueue.global(qos: .userInteractive).async {
            self.session.startRunning()
        }
    }

    final func stopRunning() {
        guard running else {
            return
        }
        session.stopRunning()
    }
}
#else
extension AVMixer: Running {
    // MARK: Running
    var running: Bool {
        return false
    }
    final func startRunning() {
    }
    final func stopRunning() {
    }
}
#endif
