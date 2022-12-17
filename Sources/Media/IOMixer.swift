import AVFoundation

#if os(iOS) || os(macOS)
extension AVCaptureSession.Preset {
    static var `default`: AVCaptureSession.Preset = .medium
}
#endif

protocol IOMixerDelegate: AnyObject {
    func mixer(_ mixer: IOMixer, didOutput audio: AVAudioPCMBuffer, presentationTimeStamp: CMTime)
    func mixer(_ mixer: IOMixer, didOutput video: CMSampleBuffer)
}

/// An object that mixies audio and video for streaming.
public class IOMixer {
    /// The default fps for an IOMixer, value is 30.
    public static let defaultFPS: Float64 = 30

    #if os(iOS) || os(macOS)
    /// The AVCaptureSession options.
    public enum Option: String, KeyPathRepresentable, CaseIterable {
        /// Specifies the fps.
        case fps
        /// Specifie the sessionPreset.
        case sessionPreset
        /// Specifies the video is mirrored.
        case isVideoMirrored
        /// Specifies the audofocus mode continuous.
        case continuousAutofocus
        /// Specifies the exposure mode  continuous.
        case continuousExposure

        #if os(iOS)
        /// Specifies the video stabilization mode
        /// -seealso: https://github.com/shogo4405/HaishinKit.swift/discussions/1012
        case preferredVideoStabilizationMode
        #endif

        public var keyPath: AnyKeyPath {
            switch self {
            case .fps:
                return \IOMixer.fps
            case .sessionPreset:
                return \IOMixer.sessionPreset
            case .continuousAutofocus:
                return \IOMixer.continuousAutofocus
            case .continuousExposure:
                return \IOMixer.continuousExposure
            case .isVideoMirrored:
                return \IOMixer.isVideoMirrored
            #if os(iOS)
            case .preferredVideoStabilizationMode:
                return \IOMixer.preferredVideoStabilizationMode
            #endif
            }
        }
    }
    #else
    /// The AVCaptureSession options. This is a stub.
    public struct Option: KeyPathRepresentable {
        public static var allCases: [IOMixer.Option] = []
        public var keyPath: AnyKeyPath
        // swiftlint:disable nesting
        public typealias AllCases = [Option]
    }
    #endif

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

    #if os(iOS)
    var preferredVideoStabilizationMode: AVCaptureVideoStabilizationMode {
        get {
            videoIO.preferredVideoStabilizationMode
        }
        set {
            videoIO.preferredVideoStabilizationMode = newValue
        }
    }
    #endif

    #if os(iOS) || os(macOS)
    var fps: Float64 {
        get {
            videoIO.fps
        }
        set {
            videoIO.fps = newValue
        }
    }

    var isVideoMirrored: Bool {
        get {
            videoIO.isVideoMirrored
        }
        set {
            videoIO.isVideoMirrored = newValue
        }
    }

    var continuousExposure: Bool {
        get {
            videoIO.continuousExposure
        }
        set {
            videoIO.continuousExposure = newValue
        }
    }

    var continuousAutofocus: Bool {
        get {
            videoIO.continuousAutofocus
        }
        set {
            videoIO.continuousAutofocus = newValue
        }
    }

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

    var settings: Setting<IOMixer, Option> = [:] {
        didSet {
            settings.observer = self
        }
    }

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

    /// Create a IOMixer instance.
    public init() {
        settings.observer = self
    }

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
