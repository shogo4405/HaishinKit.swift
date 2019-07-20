import AVFoundation

#if os(iOS) || os(macOS)
    extension AVCaptureSession.Preset {
        static var `default`: AVCaptureSession.Preset = .medium
    }
#endif

protocol AVMixerDelegate: class {
    func didOutputAudio(_ buffer: AVAudioPCMBuffer, presentationTimeStamp: CMTime)
    func didOutputVideo(_ buffer: CMSampleBuffer)
}

public class AVMixer: NSObject {
    public static let bufferEmpty: Notification.Name = .init("AVMixerBufferEmpty")

    public static let defaultFPS: Float64 = 30
    public static let defaultVideoSettings: [NSString: AnyObject] = [
        kCVPixelBufferPixelFormatTypeKey: NSNumber(value: kCVPixelFormatType_32BGRA)
    ]

    #if os(iOS)
    static let supportedSettingsKeys: [String] = [
        "fps",
        "sessionPreset",
        "continuousAutofocus",
        "continuousExposure",
        "preferredVideoStabilizationMode"
    ]

    @objc var preferredVideoStabilizationMode: AVCaptureVideoStabilizationMode {
        get { return videoIO.preferredVideoStabilizationMode }
        set { videoIO.preferredVideoStabilizationMode = newValue }
    }
    #elseif os(macOS)
    static let supportedSettingsKeys: [String] = [
        "fps",
        "sessionPreset",
        "continuousAutofocus",
        "continuousExposure"
    ]
    #else
    static let supportedSettingsKeys: [String] = [
    ]
    #endif

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

    weak var delegate: AVMixerDelegate?

    private var _recorder: AVRecorder?
    /// The recorder instance.
    public var recorder: AVRecorder! {
        if _recorder == nil {
            _recorder = AVRecorder()
        }
        return _recorder
    }

    private var _audioIO: AudioIOComponent?
    var audioIO: AudioIOComponent! {
        if _audioIO == nil {
            _audioIO = AudioIOComponent(mixer: self)
        }
        return _audioIO!
    }

    private var _videoIO: VideoIOComponent?
    var videoIO: VideoIOComponent! {
        if _videoIO == nil {
            _videoIO = VideoIOComponent(mixer: self)
        }
        return _videoIO!
    }

    deinit {
        dispose()
    }

    public func dispose() {
#if os(iOS) || os(macOS)
        if let session = _session, session.isRunning {
            session.stopRunning()
        }
#endif
        _audioIO?.dispose()
        _audioIO = nil
        _videoIO?.dispose()
        _videoIO = nil
    }

    func didBufferEmpty(_ component: IOComponent) {
        NotificationCenter.default.post(.init(name: AVMixer.bufferEmpty))
    }
}

extension AVMixer {
    public func startEncoding(delegate: Any) {
        videoIO.encoder.delegate = delegate as? VideoEncoderDelegate
        videoIO.encoder.startRunning()
        audioIO.encoder.delegate = delegate as? AudioConverterDelegate
        audioIO.encoder.startRunning()
    }

    public func stopEncoding() {
        videoIO.encoder.delegate = nil
        videoIO.encoder.stopRunning()
        audioIO.encoder.delegate = nil
        audioIO.encoder.stopRunning()
    }
}

extension AVMixer {
    public func startPlaying(_ audioEngine: AVAudioEngine?) {
        audioIO.audioEngine = audioEngine
        audioIO.encoder.delegate = audioIO
        videoIO.queue.startRunning()
        videoIO.decoder.startRunning()
    }

    public func stopPlaying() {
        audioIO.audioEngine = nil
        audioIO.encoder.delegate = nil
        videoIO.queue.stopRunning()
        videoIO.decoder.stopRunning()
    }
}

#if os(iOS) || os(macOS)
extension AVMixer: Running {
    // MARK: Running
    public var isRunning: Atomic<Bool> {
        return .init(session.isRunning)
    }

    public func startRunning() {
        guard !isRunning.value else {
            return
        }
        DispatchQueue.global(qos: .userInteractive).async {
            self.session.startRunning()
        }
    }

    public func stopRunning() {
        guard isRunning.value else {
            return
        }
        session.stopRunning()
    }
}
#else
extension AVMixer: Running {
    // MARK: Running
    public var isRunning: Atomic<Bool> {
        return .init(false)
    }

    public func startRunning() {
    }

    public func stopRunning() {
    }
}
#endif
