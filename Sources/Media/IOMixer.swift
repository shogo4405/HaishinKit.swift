import AVFoundation

#if os(iOS) || os(macOS)
extension AVCaptureSession.Preset {
    static var `default`: AVCaptureSession.Preset = AVCaptureSession.Preset.hd1280x720
}
#endif

protocol IOMixerDelegate: AnyObject {
    func mixer(_ mixer: IOMixer, didOutput audio: AVAudioPCMBuffer, presentationTimeStamp: CMTime)
    func mixer(_ mixer: IOMixer, didOutput video: CMSampleBuffer)
}

/// An object that mixies audio and video for streaming.
public class IOMixer {
    /// The default fps for an IOMixer, value is 30.
    public static let defaultFrameRate: Float64 = 30

    enum MediaSync {
        case video
        case passthrough
    }

    var isMultiCamSessionEnabled = false {
        didSet {
            guard oldValue != isMultiCamSessionEnabled else {
                return
            }
            #if os(iOS)
            if #available(iOS 13.0, *) {
                if isMultiCamSessionEnabled {
                    if !(session is AVCaptureMultiCamSession) {
                        session = AVCaptureMultiCamSession()
                    }
                } else {
                    if session is AVCaptureMultiCamSession {
                        session = AVCaptureSession()
                    }
                }
            }
            #endif
        }
    }

    #if os(iOS) || os(macOS)
    var sessionPreset: AVCaptureSession.Preset = .default {
        didSet {
            guard sessionPreset != oldValue, session.canSetSessionPreset(sessionPreset) else {
                return
            }
            session.beginConfiguration()
            session.sessionPreset = sessionPreset
            session.commitConfiguration()
        }
    }

    /// The capture session instance.
    public internal(set) lazy var session: AVCaptureSession = {
        let session = AVCaptureSession()
        if session.canSetSessionPreset(sessionPreset) {
            session.sessionPreset = sessionPreset
        }
        return session
    }() {
        didSet {
            if oldValue.isRunning {
                oldValue.stopRunning()
            }
            audioIO.capture?.detachSession(oldValue)
            videoIO.capture?.detachSession(oldValue)
            if session.canSetSessionPreset(sessionPreset) {
                session.sessionPreset = sessionPreset
            }
            audioIO.capture?.attachSession(session)
            videoIO.capture?.attachSession(session)
        }
    }
    #endif
    /// The recorder instance.
    public lazy var recorder = IORecorder()

    /// Specifies the drawable object.
    public weak var drawable: NetStreamDrawable? {
        get {
            videoIO.drawable
        }
        set {
            videoIO.drawable = newValue
        }
    }

    var mediaSync = MediaSync.passthrough

    weak var delegate: IOMixerDelegate?

    lazy var audioIO: IOAudioUnit = {
        var audioIO = IOAudioUnit()
        audioIO.mixer = self
        return audioIO
    }()

    lazy var videoIO: IOVideoUnit = {
        var videoIO = IOVideoUnit()
        videoIO.mixer = self
        return videoIO
    }()

    lazy var mediaLink: MediaLink = {
        var mediaLink = MediaLink()
        mediaLink.delegate = self
        return mediaLink
    }()

    private var audioTimeStamp = CMTime.zero
    private var videoTimeStamp = CMTime.zero

    #if os(iOS) || os(macOS)
    deinit {
        if session.isRunning {
            session.stopRunning()
        }
    }
    #endif

    func useSampleBuffer(sampleBuffer: CMSampleBuffer, mediaType: AVMediaType) -> Bool {
        switch mediaSync {
        case .video:
            if mediaType == .audio {
                return !videoTimeStamp.seconds.isZero && videoTimeStamp.seconds <= sampleBuffer.presentationTimeStamp.seconds
            }
            if videoTimeStamp == CMTime.zero {
                videoTimeStamp = sampleBuffer.presentationTimeStamp
            }
            return true
        default:
            return true
        }
    }

    @objc
    private func didEnterBackground(_ notification: Notification) {
        #if os(iOS) || os(macOS)
        videoIO.multiCamCapture?.detachSession(session)
        videoIO.capture?.detachSession(session)
        #endif
    }

    @objc
    private func didBecomeActive(_ notification: Notification) {
        #if os(iOS) || os(macOS)
        videoIO.capture?.attachSession(session)
        videoIO.multiCamCapture?.attachSession(session)
        #endif
    }
}

extension IOMixer: IOUnitEncoding {
    /// Starts encoding for video and audio data.
    public func startEncoding(_ delegate: AVCodecDelegate) {
        videoIO.startEncoding(delegate)
        audioIO.startEncoding(delegate)
    }

    /// Stop encoding.
    public func stopEncoding() {
        videoTimeStamp = CMTime.zero
        audioTimeStamp = CMTime.zero
        videoIO.stopEncoding()
        audioIO.stopEncoding()
    }
}

extension IOMixer: IOUnitDecoding {
    /// Starts decoding for video and audio data.
    public func startDecoding(_ audioEngine: AVAudioEngine) {
        mediaLink.startRunning()
        audioIO.startDecoding(audioEngine)
        videoIO.startDecoding(audioEngine)
    }

    /// Stop decoding.
    public func stopDecoding() {
        mediaLink.stopRunning()
        audioIO.stopDecoding()
        videoIO.stopDecoding()
    }
}

extension IOMixer: MediaLinkDelegate {
    // MARK: MediaLinkDelegate
    func mediaLink(_ mediaLink: MediaLink, dequeue sampleBuffer: CMSampleBuffer) {
        videoIO.codec.inputBuffer(sampleBuffer)
    }

    func mediaLink(_ mediaLink: MediaLink, didBufferingChanged: Bool) {
        logger.info(didBufferingChanged)
    }
}

#if os(iOS) || os(macOS)
extension IOMixer: Running {
    // MARK: Running
    public var isRunning: Atomic<Bool> {
        .init(session.isRunning)
    }

    public func startRunning() {
        guard !isRunning.value else {
            return
        }
        #if os(iOS)
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground(_:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActive(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)
        #endif
        session.startRunning()
    }

    public func stopRunning() {
        guard isRunning.value else {
            return
        }
        #if os(iOS)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
        #endif
        session.stopRunning()
    }
}
#else
extension IOMixer: Running {
    // MARK: Running
    public var isRunning: Atomic<Bool> {
        .init(false)
    }

    public func startRunning() {
    }

    public func stopRunning() {
    }
}
#endif
