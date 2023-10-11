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
    func mixer(_ mixer: IOMixer, videoErrorOccurred error: IOMixerVideoError)
    func mixer(_ mixer: IOMixer, audioErrorOccurred error: IOMixerAudioError)
    #if os(iOS) || os(tvOS)
    @available(tvOS 17.0, *)
    func mixer(_ mixer: IOMixer, sessionWasInterrupted session: AVCaptureSession, reason: AVCaptureSession.InterruptionReason?)
    @available(tvOS 17.0, *)
    func mixer(_ mixer: IOMixer, sessionInterruptionEnded session: AVCaptureSession)
    #endif
}

/**
 * The IOMixer video error domain codes.
 */
public enum IOMixerVideoError: Swift.Error {
    /// The IOMixer video  failed to create the VTSession.
    case failedToCreate(status: OSStatus)
    /// The IOMixer video  failed to prepare the VTSession.
    case failedToPrepare(status: OSStatus)
    /// The IOMixer video  failed to encode or decode a flame.
    case failedToFlame(status: OSStatus)
    /// The IOMixer video  failed to set an option.
    case failedToSetOption(status: OSStatus, option: VTSessionOption)
}

/// The IOMixer audio  error domain codes.
public enum IOMixerAudioError: Swift.Error {
    /// The IOMixer audio  failed to create the AVAudioConverter..
    case failedToCreate(from: AVAudioFormat?, to: AVAudioFormat?)
    /// THe IOMixer audio faild to convert the an audio buffer.
    case failedToConvert(error: NSError)
}

/// An object that mixies audio and video for streaming.
public final class IOMixer {
    /// The default fps for an IOMixer, value is 30.
    public static let defaultFrameRate: Float64 = 30
    /// The AVAudioEngine shared instance holder.
    public static let audioEngineHolder: InstanceHolder<AVAudioEngine> = .init {
        return AVAudioEngine()
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
    public weak var drawable: (any NetStreamDrawable)? {
        get {
            videoIO.drawable
        }
        set {
            videoIO.drawable = newValue
        }
    }

    public weak var muxer: (any IOMuxer)?

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

    lazy var mediaLink: MediaLink = {
        var mediaLink = MediaLink<IOMixer>()
        mediaLink.delegate = self
        return mediaLink
    }()

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

extension IOMixer: IOUnitEncoding {
    /// Starts encoding for video and audio data.
    public func startEncoding() {
        videoIO.startEncoding()
        audioIO.startEncoding()
    }

    /// Stop encoding.
    public func stopEncoding() {
        videoIO.stopEncoding()
        audioIO.stopEncoding()
    }
}

extension IOMixer: IOUnitDecoding {
    /// Starts decoding for video and audio data.
    public func startDecoding() {
        audioIO.startDecoding()
        videoIO.startDecoding()
        mediaLink.startRunning()
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
    func mediaLink(_ mediaLink: MediaLink<IOMixer>, dequeue sampleBuffer: CMSampleBuffer) {
        delegate?.mixer(self, didOutput: sampleBuffer)
        drawable?.enqueue(sampleBuffer)
    }

    func mediaLink(_ mediaLink: MediaLink<IOMixer>, didBufferingChanged: Bool) {
        logger.info(didBufferingChanged)
    }
}

#if os(iOS) || os(macOS) || os(tvOS)
extension IOMixer: Running {
    // MARK: Running
    public func startRunning() {
        guard !isRunning.value else {
            return
        }
        if #available(tvOS 17.0, *) {
            addSessionObservers(session)
            session.startRunning()
            isRunning.mutate { $0 = session.isRunning }
        }
    }

    public func stopRunning() {
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
            #if os(iOS) || os(tvOS)
            let isMultiCamSupported: Bool
            if #available(iOS 13.0, *) {
                isMultiCamSupported = session is AVCaptureMultiCamSession
            } else {
                isMultiCamSupported = false
            }
            #else
            let isMultiCamSupported = true
            #endif
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

extension IOMixer: VideoCodecDelegate {
    // MARK: VideoCodecDelegate
    func videoCodec(_ codec: VideoCodec, didOutput formatDescription: CMFormatDescription?) {
        muxer?.videoFormat = formatDescription
    }

    func videoCodec(_ codec: VideoCodec, didOutput sampleBuffer: CMSampleBuffer) {
        switch sampleBuffer.formatDescription?._mediaSubType {
        case kCVPixelFormatType_1Monochrome,
             kCVPixelFormatType_2Indexed,
             kCVPixelFormatType_8Indexed,
             kCVPixelFormatType_1IndexedGray_WhiteIsZero,
             kCVPixelFormatType_2IndexedGray_WhiteIsZero,
             kCVPixelFormatType_4IndexedGray_WhiteIsZero,
             kCVPixelFormatType_8IndexedGray_WhiteIsZero,
             kCVPixelFormatType_16BE555,
             kCVPixelFormatType_16LE555,
             kCVPixelFormatType_16LE5551,
             kCVPixelFormatType_16BE565,
             kCVPixelFormatType_16LE565,
             kCVPixelFormatType_24RGB,
             kCVPixelFormatType_24BGR,
             kCVPixelFormatType_32ARGB,
             kCVPixelFormatType_32BGRA,
             kCVPixelFormatType_32ABGR,
             kCVPixelFormatType_32RGBA,
             kCVPixelFormatType_64ARGB,
             kCVPixelFormatType_48RGB,
             kCVPixelFormatType_32AlphaGray,
             kCVPixelFormatType_16Gray,
             kCVPixelFormatType_30RGB,
             kCVPixelFormatType_422YpCbCr8,
             kCVPixelFormatType_4444YpCbCrA8,
             kCVPixelFormatType_4444YpCbCrA8R,
             kCVPixelFormatType_4444AYpCbCr8,
             kCVPixelFormatType_4444AYpCbCr16,
             kCVPixelFormatType_444YpCbCr8,
             kCVPixelFormatType_422YpCbCr16,
             kCVPixelFormatType_422YpCbCr10,
             kCVPixelFormatType_444YpCbCr10,
             kCVPixelFormatType_420YpCbCr8Planar,
             kCVPixelFormatType_420YpCbCr8PlanarFullRange,
             kCVPixelFormatType_422YpCbCr_4A_8BiPlanar,
             kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
             kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
             kCVPixelFormatType_422YpCbCr8_yuvs,
             kCVPixelFormatType_422YpCbCr8FullRange,
             kCVPixelFormatType_OneComponent8,
             kCVPixelFormatType_TwoComponent8,
             kCVPixelFormatType_OneComponent16Half,
             kCVPixelFormatType_OneComponent32Float,
             kCVPixelFormatType_TwoComponent16Half,
             kCVPixelFormatType_TwoComponent32Float,
             kCVPixelFormatType_64RGBAHalf,
             kCVPixelFormatType_128RGBAFloat:
            mediaLink.enqueueVideo(sampleBuffer)
        default:
            muxer?.append(sampleBuffer)
        }
    }

    func videoCodec(_ codec: VideoCodec, errorOccurred error: IOMixerVideoError) {
        delegate?.mixer(self, videoErrorOccurred: error)
    }
}

extension IOMixer: AudioCodecDelegate {
    // MARK: AudioCodecDelegate
    func audioCodec(_ codec: AudioCodec<IOMixer>, didOutput audioFormat: AVAudioFormat) {
        switch audioFormat.formatDescription.audioStreamBasicDescription?.mFormatID {
        case kAudioFormatLinearPCM:
            do {
                self.audioFormat = audioFormat
                if let audioEngine = audioEngine, audioEngine.isRunning == false {
                    try audioEngine.start()
                }
            } catch {
                logger.error(error)
            }
        default:
            muxer?.audioFormat = audioFormat
        }
    }

    func audioCodec(_ codec: AudioCodec<IOMixer>, didOutput audioBuffer: AVAudioBuffer, when: AVAudioTime) {
        switch audioBuffer {
        case let audioBuffer as AVAudioPCMBuffer:
            delegate?.mixer(self, didOutput: audioBuffer, when: when)
            mediaLink.enqueueAudio(audioBuffer)
        case let audioBuffer as AVAudioCompressedBuffer:
            muxer?.append(audioBuffer, when: when)
            codec.releaseOutputBuffer(audioBuffer)
        default:
            break
        }
    }

    func audioCodec(_ codec: AudioCodec<IOMixer>, errorOccurred error: IOMixerAudioError) {
        delegate?.mixer(self, audioErrorOccurred: error)
    }
}

extension IOMixer: IOAudioUnitDelegate {
    // MARK: IOAudioUnitDelegate
    func audioUnit(_ audioUnit: IOAudioUnit, errorOccurred error: IOMixerAudioError) {
        delegate?.mixer(self, audioErrorOccurred: error)
    }

    func audioUnit(_ audioUnit: IOAudioUnit, didOutput audioBuffer: AVAudioPCMBuffer, when: AVAudioTime) {
        delegate?.mixer(self, didOutput: audioBuffer, when: when)
        recorder.append(audioBuffer, when: when)
    }
}
