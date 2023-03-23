import AVFoundation
#if canImport(SwiftPMSupport)
import SwiftPMSupport
#endif

#if os(iOS)
import UIKit
#endif
#if os(iOS) || os(macOS)
extension AVCaptureSession.Preset {
    static let `default`: AVCaptureSession.Preset = .hd1280x720
}
#endif

protocol IOMixerDelegate: AnyObject {
    func mixer(_ mixer: IOMixer, didOutput audio: AVAudioPCMBuffer, presentationTimeStamp: CMTime)
    func mixer(_ mixer: IOMixer, didOutput video: CMSampleBuffer)
    #if os(iOS)
    func mixer(_ mixer: IOMixer, sessionWasInterrupted session: AVCaptureSession, reason: AVCaptureSession.InterruptionReason)
    func mixer(_ mixer: IOMixer, sessionInterruptionEnded session: AVCaptureSession, reason: AVCaptureSession.InterruptionReason)
    #endif
}

/// An object that mixies audio and video for streaming.
public class IOMixer {
    /// The default fps for an IOMixer, value is 30.
    public static let defaultFrameRate: Float64 = 30
    /// The AVAudioEngine shared instance holder.
    public static let audioEngineHolder: InstanceHolder<AVAudioEngine> = .init {
        return AVAudioEngine()
    }

    enum MediaSync {
        case video
        case passthrough
    }

    enum ReadyState {
        case standby
        case encoding
        case decoding
    }

    public var hasVideo: Bool {
        get {
            mediaLink.hasVideo
        }
        set {
            mediaLink.hasVideo = newValue
        }
    }

    public var isPaused: Bool {
        get {
            mediaLink.isPaused
        }
        set {
            mediaLink.isPaused = newValue
        }
    }

    var audioFormat: AVAudioFormat? {
        didSet {
            guard let audioEngine else {
                return
            }
            nstry({
                if let audioFormat = self.audioFormat {
                    audioEngine.connect(self.mediaLink.playerNode, to: audioEngine.mainMixerNode, format: audioFormat)
                } else {
                    audioEngine.disconnectNodeInput(self.mediaLink.playerNode)
                }
            }, { exeption in
                logger.warn(exeption)
            })
        }
    }

    private var readyState: ReadyState = .standby
    private(set) lazy var audioEngine: AVAudioEngine? = {
        return IOMixer.audioEngineHolder.retain()
    }()

    #if os(iOS) || os(macOS)
    var isMultitaskingCameraAccessEnabled = true

    var isMultiCamSessionEnabled = false {
        didSet {
            guard oldValue != isMultiCamSessionEnabled else {
                return
            }
            #if os(iOS)
            session = makeSession()
            #endif
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
    public internal(set) lazy var session: AVCaptureSession = makeSession() {
        didSet {
            if oldValue.isRunning {
                removeSessionObservers(oldValue)
                oldValue.stopRunning()
            }
            audioIO.capture.detachSession(oldValue)
            videoIO.capture.detachSession(oldValue)
            if session.canSetSessionPreset(sessionPreset) {
                session.sessionPreset = sessionPreset
            }
            audioIO.capture.attachSession(session)
            videoIO.capture.attachSession(session)
        }
    }
    #endif
    public private(set) var isRunning: Atomic<Bool> = .init(false)
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

    #if os(iOS) || os(macOS)
    deinit {
        if session.isRunning {
            session.stopRunning()
        }
        IOMixer.audioEngineHolder.release(audioEngine)
    }
    #endif

    private var audioTimeStamp = CMTime.zero
    private var videoTimeStamp = CMTime.zero

    /// Append a CMSampleBuffer with media type.
    public func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        switch readyState {
        case .encoding:
            break
        case .decoding:
            switch sampleBuffer.formatDescription?.mediaType {
            case kCMMediaType_Audio:
                audioIO.codec.appendSampleBuffer(sampleBuffer)
            case kCMMediaType_Video:
                videoIO.codec.formatDescription = sampleBuffer.formatDescription
                mediaLink.enqueueVideo(sampleBuffer)
            default:
                break
            }
        case .standby:
            break
        }
    }

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

    #if os(iOS)
    private func makeSession() -> AVCaptureSession {
        let session: AVCaptureSession
        if isMultiCamSessionEnabled, #available(iOS 13.0, *) {
            session = AVCaptureMultiCamSession()
        } else {
            session = AVCaptureSession()
        }
        if session.canSetSessionPreset(sessionPreset) {
            session.sessionPreset = sessionPreset
        }
        if #available(iOS 16.0, *), isMultitaskingCameraAccessEnabled, session.isMultitaskingCameraAccessSupported {
            session.isMultitaskingCameraAccessEnabled = true
        }
        return session
    }
    #endif

    #if os(macOS)
    private func makeSession() -> AVCaptureSession {
        let session = AVCaptureSession()
        if session.canSetSessionPreset(sessionPreset) {
            session.sessionPreset = sessionPreset
        }
        return session
    }
    #endif
}

extension IOMixer: IOUnitEncoding {
    /// Starts encoding for video and audio data.
    public func startEncoding(_ delegate: AVCodecDelegate) {
        guard readyState == .standby else {
            return
        }
        readyState = .encoding
        videoIO.startEncoding(delegate)
        audioIO.startEncoding(delegate)
    }

    /// Stop encoding.
    public func stopEncoding() {
        guard readyState == .encoding else {
            return
        }
        videoTimeStamp = CMTime.zero
        audioTimeStamp = CMTime.zero
        videoIO.stopEncoding()
        audioIO.stopEncoding()
        readyState = .standby
    }
}

extension IOMixer: IOUnitDecoding {
    /// Starts decoding for video and audio data.
    public func startDecoding() {
        guard readyState == .standby else {
            return
        }
        audioIO.startDecoding()
        videoIO.startDecoding()
        mediaLink.startRunning()
        readyState = .decoding
    }

    /// Stop decoding.
    public func stopDecoding() {
        guard readyState == .decoding else {
            return
        }
        mediaLink.stopRunning()
        audioIO.stopDecoding()
        videoIO.stopDecoding()
        readyState = .standby
    }
}

extension IOMixer: MediaLinkDelegate {
    // MARK: MediaLinkDelegate
    func mediaLink(_ mediaLink: MediaLink, dequeue sampleBuffer: CMSampleBuffer) {
        videoIO.codec.appendSampleBuffer(sampleBuffer)
    }

    func mediaLink(_ mediaLink: MediaLink, didBufferingChanged: Bool) {
        logger.info(didBufferingChanged)
    }
}

#if os(iOS) || os(macOS)
extension IOMixer: Running {
    // MARK: Running
    public func startRunning() {
        guard !isRunning.value else {
            return
        }
        #if os(iOS)
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground(_:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActive(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)
        #endif
        addSessionObservers(session)
        session.startRunning()
        isRunning.mutate { $0 = session.isRunning }
    }

    public func stopRunning() {
        guard isRunning.value else {
            return
        }
        removeSessionObservers(session)
        session.stopRunning()
        #if os(iOS)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
        #endif
        isRunning.mutate { $0 = session.isRunning }
    }

    private func addSessionObservers(_ session: AVCaptureSession) {
        NotificationCenter.default.addObserver(self, selector: #selector(sessionRuntimeError(_:)), name: .AVCaptureSessionRuntimeError, object: session)
        #if os(iOS)
        NotificationCenter.default.addObserver(self, selector: #selector(sessionInterruptionEnded(_:)), name: .AVCaptureSessionInterruptionEnded, object: session)
        NotificationCenter.default.addObserver(self, selector: #selector(sessionWasInterrupted(_:)), name: .AVCaptureSessionWasInterrupted, object: session)
        #endif
    }

    private func removeSessionObservers(_ session: AVCaptureSession) {
        #if os(iOS)
        NotificationCenter.default.removeObserver(self, name: .AVCaptureSessionWasInterrupted, object: session)
        NotificationCenter.default.removeObserver(self, name: .AVCaptureSessionInterruptionEnded, object: session)
        #endif
        NotificationCenter.default.removeObserver(self, name: .AVCaptureSessionRuntimeError, object: session)
    }

    @objc
    private func sessionRuntimeError(_ notification: NSNotification) {
        guard
            let errorValue = notification.userInfo?[AVCaptureSessionErrorKey] as? NSError else {
            return
        }
        let error = AVError(_nsError: errorValue)
        switch error.code {
        case .unsupportedDeviceActiveFormat:
            #if os(iOS)
            let isMultiCamSupported: Bool
            if #available(iOS 13.0, *) {
                isMultiCamSupported = session is AVCaptureMultiCamSession
            } else {
                isMultiCamSupported = false
            }
            #else
            let isMultiCamSupported = true
            #endif
            guard let device = error.device,
                  let format = device.videoFormat(
                    width: sessionPreset.width ?? videoIO.codec.settings.videoSize.width,
                    height: sessionPreset.height ?? videoIO.codec.settings.videoSize.height,
                    isMultiCamSupported: isMultiCamSupported
                  ), device.activeFormat != format else {
                return
            }
            do {
                try device.lockForConfiguration()
                device.activeFormat = format
                if let duration = format.getFrameRate(videoIO.frameRate) {
                    device.activeVideoMinFrameDuration = duration
                    device.activeVideoMaxFrameDuration = duration
                }
                device.unlockForConfiguration()
                session.startRunning()
            } catch {
                logger.warn(error)
            }
        #if os(iOS)
        case .mediaServicesWereReset:
            guard isRunning.value else {
                return
            }
            if !session.isRunning {
                session.startRunning()
                isRunning.mutate { $0 = session.isRunning }
            }
        #endif
        default:
            break
        }
    }

    #if os(iOS)
    @objc
    private func sessionWasInterrupted(_ notification: Notification) {
        guard let userInfoValue = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as AnyObject?,
              let reasonIntegerValue = userInfoValue.integerValue,
              let reason = AVCaptureSession.InterruptionReason(rawValue: reasonIntegerValue),
              let session = notification.object as? AVCaptureSession else {
            return
        }
        delegate?.mixer(self, sessionWasInterrupted: session, reason: reason)
    }

    @objc
    private func sessionInterruptionEnded(_ notification: Notification) {
        guard let userInfoValue = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as AnyObject?,
              let reasonIntegerValue = userInfoValue.integerValue,
              let reason = AVCaptureSession.InterruptionReason(rawValue: reasonIntegerValue),
              let session = notification.object as? AVCaptureSession else {
            return
        }
        delegate?.mixer(self, sessionInterruptionEnded: session, reason: reason)
    }

    @objc
    private func didEnterBackground(_ notification: Notification) {
        if #available(iOS 16, *) {
            guard !session.isMultitaskingCameraAccessEnabled else {
                return
            }
        }
        videoIO.multiCamCapture.detachSession(session)
        videoIO.capture.detachSession(session)
    }

    @objc
    private func didBecomeActive(_ notification: Notification) {
        if #available(iOS 16, *) {
            guard !session.isMultitaskingCameraAccessEnabled else {
                return
            }
        }
        videoIO.capture.attachSession(session)
        videoIO.multiCamCapture.attachSession(session)
    }
    #endif
}
#else
extension IOMixer: Running {
    public func startRunning() {
    }

    public func stopRunning() {
    }
}
#endif
