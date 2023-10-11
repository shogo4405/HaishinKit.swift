import AVFoundation
#if canImport(SwiftPMSupport)
import SwiftPMSupport
#endif
#if os(iOS)
import UIKit
#endif

protocol IOMixerDelegate: AnyObject {
    func mixer(_ mixer: IOMixer, didOutput audio: AVAudioPCMBuffer, when: AVAudioTime)
    func mixer(_ mixer: IOMixer, didOutput video: CMSampleBuffer)
    func mixer(_ mixer: IOMixer, videoErrorOccurred error: IOVideoUnitError)
    func mixer(_ mixer: IOMixer, audioErrorOccurred error: IOAudioUnitError)
    #if os(iOS) || os(tvOS)
    @available(tvOS 17.0, *)
    func mixer(_ mixer: IOMixer, sessionWasInterrupted session: AVCaptureSession, reason: AVCaptureSession.InterruptionReason?)
    @available(tvOS 17.0, *)
    func mixer(_ mixer: IOMixer, sessionInterruptionEnded session: AVCaptureSession)
    #endif
}

/// An object that mixies audio and video for streaming.
final class IOMixer {
    /// The default fps for an IOMixer, value is 30.
    static let defaultFrameRate: Float64 = 30
    /// The AVAudioEngine shared instance holder.
    static let audioEngineHolder: InstanceHolder<AVAudioEngine> = .init {
        return AVAudioEngine()
    }

    #if os(tvOS)
    private var _session: Any?
    /// The capture session instance.
    @available(tvOS 17.0, *)
    public var session: AVCaptureSession {
        get {
            if _session == nil {
                _session = makeSession()
            }
            return _session as! AVCaptureSession
        }
        set {
            _session = newValue
        }
    }
    #elseif os(iOS) || os(macOS)
    /// The capture session instance.
    lazy var session: AVCaptureSession = makeSession() {
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

    private(set) var isRunning: Atomic<Bool> = .init(false)
    /// The recorder instance.
    private(set) lazy var recorder = IORecorder()

    weak var muxer: (any IOMuxer)?
    weak var delegate: (any IOMixerDelegate)?

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

    #if os(tvOS)
    private var _sessionPreset: Any?
    @available(tvOS 17.0, *)
    var sessionPreset: AVCaptureSession.Preset {
        get {
            if _sessionPreset == nil {
                _sessionPreset = AVCaptureSession.Preset.default
            }
            return _sessionPreset as! AVCaptureSession.Preset
        }
        set {
            guard sessionPreset != newValue, session.canSetSessionPreset(newValue) else {
                return
            }
            session.beginConfiguration()
            session.sessionPreset = newValue
            session.commitConfiguration()
        }
    }
    #elseif os(iOS) || os(macOS)
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
    #endif

    #if os(iOS) || os(macOS) || os(tvOS)
    var inBackgroundMode = false {
        didSet {
            if #available(tvOS 17.0, *) {
                guard inBackgroundMode != oldValue else {
                    return
                }
                if inBackgroundMode {
                    if !session.isMultitaskingCameraAccessEnabled {
                        videoIO.multiCamCapture.detachSession(session)
                        videoIO.capture.detachSession(session)
                    }
                } else {
                    startCaptureSessionIfNeeded()
                    if !session.isMultitaskingCameraAccessEnabled {
                        videoIO.capture.attachSession(session)
                        videoIO.multiCamCapture.attachSession(session)
                    }
                }
            }
        }
    }
    #endif

    private(set) lazy var audioEngine: AVAudioEngine? = {
        return IOMixer.audioEngineHolder.retain()
    }()

    private var isMultiCamSupported: Bool {
        #if os(iOS) || os(tvOS)
        if #available(iOS 13.0, *) {
            return session is AVCaptureMultiCamSession
        } else {
            return false
        }
        #else
        return false
        #endif
    }

    deinit {
        #if os(iOS) || os(macOS) || os(tvOS)
        if #available(tvOS 17.0, *) {
            if session.isRunning {
                session.stopRunning()
            }
        }
        #endif
        IOMixer.audioEngineHolder.release(audioEngine)
    }

    #if os(iOS) || os(tvOS)
    @available(tvOS 17.0, *)
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
        if session.isMultitaskingCameraAccessSupported {
            session.isMultitaskingCameraAccessEnabled = true
        }
        return session
    }
    #elseif os(macOS)
    private func makeSession() -> AVCaptureSession {
        let session = AVCaptureSession()
        if session.canSetSessionPreset(sessionPreset) {
            session.sessionPreset = sessionPreset
        }
        return session
    }
    #endif
}

#if os(iOS) || os(macOS) || os(tvOS)
extension IOMixer: Running {
    // MARK: Running
    func startRunning() {
        guard !isRunning.value else {
            return
        }
        if #available(tvOS 17.0, *) {
            addSessionObservers(session)
            session.startRunning()
            isRunning.mutate { $0 = session.isRunning }
        }
    }

    func stopRunning() {
        guard isRunning.value else {
            return
        }
        if #available(tvOS 17.0, *) {
            removeSessionObservers(session)
            session.stopRunning()
            isRunning.mutate { $0 = session.isRunning }
        }
    }

    @available(tvOS 17.0, *)
    func startCaptureSessionIfNeeded() {
        guard isRunning.value && !session.isRunning else {
            return
        }
        session.startRunning()
        isRunning.mutate { $0 = session.isRunning }
    }

    @available(tvOS 17.0, *)
    private func addSessionObservers(_ session: AVCaptureSession) {
        NotificationCenter.default.addObserver(self, selector: #selector(sessionRuntimeError(_:)), name: .AVCaptureSessionRuntimeError, object: session)
        #if os(iOS) || os(tvOS)
        NotificationCenter.default.addObserver(self, selector: #selector(sessionInterruptionEnded(_:)), name: .AVCaptureSessionInterruptionEnded, object: session)
        NotificationCenter.default.addObserver(self, selector: #selector(sessionWasInterrupted(_:)), name: .AVCaptureSessionWasInterrupted, object: session)
        #endif
    }

    @available(tvOS 17.0, *)
    private func removeSessionObservers(_ session: AVCaptureSession) {
        #if os(iOS) || os(tvOS)
        NotificationCenter.default.removeObserver(self, name: .AVCaptureSessionWasInterrupted, object: session)
        NotificationCenter.default.removeObserver(self, name: .AVCaptureSessionInterruptionEnded, object: session)
        #endif
        NotificationCenter.default.removeObserver(self, name: .AVCaptureSessionRuntimeError, object: session)
    }

    @available(tvOS 17.0, *)
    @objc
    private func sessionRuntimeError(_ notification: NSNotification) {
        guard
            let errorValue = notification.userInfo?[AVCaptureSessionErrorKey] as? NSError else {
            return
        }
        let error = AVError(_nsError: errorValue)
        switch error.code {
        case .unsupportedDeviceActiveFormat:
            guard let device = error.device, let format = device.videoFormat(
                width: sessionPreset.width ?? Int32(videoIO.settings.videoSize.width),
                height: sessionPreset.height ?? Int32(videoIO.settings.videoSize.height),
                frameRate: videoIO.frameRate,
                isMultiCamSupported: isMultiCamSupported
            ), device.activeFormat != format else {
                return
            }
            do {
                try device.lockForConfiguration()
                device.activeFormat = format
                if format.isFrameRateSupported(videoIO.frameRate) {
                    device.activeVideoMinFrameDuration = CMTime(value: 100, timescale: CMTimeScale(100 * videoIO.frameRate))
                    device.activeVideoMaxFrameDuration = CMTime(value: 100, timescale: CMTimeScale(100 * videoIO.frameRate))
                }
                device.unlockForConfiguration()
                session.startRunning()
            } catch {
                logger.warn(error)
            }
        #if os(iOS) || os(tvOS)
        case .mediaServicesWereReset:
            startCaptureSessionIfNeeded()
        #endif
        default:
            break
        }
    }

    #if os(iOS) || os(tvOS)
    @available(tvOS 17.0, *)
    @objc
    private func sessionWasInterrupted(_ notification: Notification) {
        guard let session = notification.object as? AVCaptureSession else {
            return
        }
        guard let userInfoValue = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as AnyObject?,
              let reasonIntegerValue = userInfoValue.integerValue,
              let reason = AVCaptureSession.InterruptionReason(rawValue: reasonIntegerValue) else {
            delegate?.mixer(self, sessionWasInterrupted: session, reason: nil)
            return
        }
        delegate?.mixer(self, sessionWasInterrupted: session, reason: reason)
    }

    @available(tvOS 17.0, *)
    @objc
    private func sessionInterruptionEnded(_ notification: Notification) {
        delegate?.mixer(self, sessionInterruptionEnded: session)
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

extension IOMixer {
    func startMuxing(_ muxer: any IOMuxer) {
        self.muxer = muxer
        muxer.startRunning()
        audioIO.startRunning()
        videoIO.startRunning()
    }

    func stopMuxing() {
        videoIO.stopRunning()
        audioIO.stopRunning()
        muxer?.stopRunning()
    }
}

extension IOMixer: VideoCodecDelegate {
    // MARK: VideoCodecDelegate
    func videoCodec(_ codec: VideoCodec<IOMixer>, didOutput formatDescription: CMFormatDescription?) {
        muxer?.videoFormat = formatDescription
    }

    func videoCodec(_ codec: VideoCodec<IOMixer>, didOutput sampleBuffer: CMSampleBuffer) {
        muxer?.append(sampleBuffer)
    }

    func videoCodec(_ codec: VideoCodec<IOMixer>, errorOccurred error: IOVideoUnitError) {
        delegate?.mixer(self, videoErrorOccurred: error)
    }
}

extension IOMixer: AudioCodecDelegate {
    // MARK: AudioCodecDelegate
    func audioCodec(_ codec: AudioCodec<IOMixer>, didOutput audioFormat: AVAudioFormat) {
        muxer?.audioFormat = audioFormat
    }

    func audioCodec(_ codec: AudioCodec<IOMixer>, didOutput audioBuffer: AVAudioBuffer, when: AVAudioTime) {
        switch audioBuffer {
        case let audioBuffer as AVAudioPCMBuffer:
            delegate?.mixer(self, didOutput: audioBuffer, when: when)
        default:
            break
        }
        muxer?.append(audioBuffer, when: when)
        codec.releaseOutputBuffer(audioBuffer)
    }

    func audioCodec(_ codec: AudioCodec<IOMixer>, errorOccurred error: IOAudioUnitError) {
        delegate?.mixer(self, audioErrorOccurred: error)
    }
}

extension IOMixer: IOAudioUnitDelegate {
    // MARK: IOAudioUnitDelegate
    func audioUnit(_ audioUnit: IOAudioUnit, errorOccurred error: IOAudioUnitError) {
        delegate?.mixer(self, audioErrorOccurred: error)
    }

    func audioUnit(_ audioUnit: IOAudioUnit, didOutput audioBuffer: AVAudioPCMBuffer, when: AVAudioTime) {
        delegate?.mixer(self, didOutput: audioBuffer, when: when)
        recorder.append(audioBuffer, when: when)
    }
}
