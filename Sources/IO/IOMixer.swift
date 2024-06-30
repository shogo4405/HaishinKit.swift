import AVFoundation

#if canImport(SwiftPMSupport)
import SwiftPMSupport
#endif

/// The interface an IOMixer uses to inform its delegate.
public protocol IOMixerDelegate: AnyObject {
    /// Tells the receiver to an audio buffer incoming.
    func mixer(_ mixer: IOMixer, track: UInt8, didInput audio: AVAudioBuffer, when: AVAudioTime)
    /// Tells the receiver to a video buffer incoming.
    func mixer(_ mixer: IOMixer, track: UInt8, didInput video: CMSampleBuffer)
    /// Tells the receiver to video error occured.
    func mixer(_ mixer: IOMixer, videoErrorOccurred error: IOVideoUnitError)
    /// Tells the receiver to audio error occured.
    func mixer(_ mixer: IOMixer, audioErrorOccurred error: IOAudioUnitError)
    #if os(iOS) || os(tvOS) || os(visionOS)
    /// Tells the receiver to session was interrupted.
    @available(tvOS 17.0, *)
    func mixer(_ mixer: IOMixer, sessionWasInterrupted session: AVCaptureSession, reason: AVCaptureSession.InterruptionReason?)
    /// Tells the receiver to session interrupted ended.
    @available(tvOS 17.0, *)
    func mixer(_ mixer: IOMixer, sessionInterruptionEnded session: AVCaptureSession)
    #endif
}

/// An object that mixies audio and video for streaming.
public final class IOMixer {
    static let defaultFrameRate: Float64 = 30

    /// The offscreen rendering object.
    public var screen: Screen {
        return videoIO.screen
    }

    #if os(iOS) || os(tvOS)
    /// Specifies the AVCaptureMultiCamSession enabled.
    /// Warning: If there is a possibility of using multiple cameras, please set it to true initially.
    @available(tvOS 17.0, *)
    public var isMultiCamSessionEnabled: Bool {
        get {
            return session.isMultiCamSessionEnabled
        }
        set {
            session.isMultiCamSessionEnabled = newValue
        }
    }
    #endif

    #if os(iOS) || os(macOS) || os(tvOS)
    /// Specifiet the device torch indicating wheter the turn on(TRUE) or not(FALSE).
    public var torch: Bool {
        get {
            return videoIO.torch
        }
        set {
            videoIO.torch = newValue
        }
    }

    /// Specifies the feature to mix multiple audio tracks. For example, it is possible to mix .appAudio and .micAudio from ReplayKit.
    /// Warning: If there is a possibility of this feature, please set it to true initially.
    public var isMultiTrackAudioMixingEnabled: Bool {
        get {
            return audioIO.isMultiTrackAudioMixingEnabled
        }
        set {
            audioIO.isMultiTrackAudioMixingEnabled = newValue
        }
    }

    /// Specifies the sessionPreset for the AVCaptureSession.
    @available(tvOS 17.0, *)
    public var sessionPreset: AVCaptureSession.Preset {
        get {
            return session.sessionPreset
        }
        set {
            session.sessionPreset = newValue
        }
    }
    #endif

    /// Specifies the audio monitoring enabled or not.
    public var isMonitoringEnabled: Bool {
        get {
            audioIO.isMonitoringEnabled
        }
        set {
            audioIO.isMonitoringEnabled = newValue
        }
    }

    /// Specifies the audio mixer settings.
    public var audioMixerSettings: IOAudioMixerSettings {
        get {
            audioIO.mixerSettings
        }
        set {
            audioIO.mixerSettings = newValue
        }
    }

    /// Specifies the video mixer settings.
    public var videoMixerSettings: IOVideoMixerSettings {
        get {
            videoIO.mixerSettings
        }
        set {
            videoIO.mixerSettings = newValue
        }
    }

    /// The audio input formats.
    public var audioInputFormats: [UInt8: AVAudioFormat] {
        return audioIO.inputFormats
    }

    /// The video input formats.
    public var videoInputFormats: [UInt8: CMFormatDescription] {
        return videoIO.inputFormats
    }

    #if os(iOS) || os(macOS)
    /// Specifies the video orientation for stream.
    public var videoOrientation: AVCaptureVideoOrientation {
        get {
            videoIO.videoOrientation
        }
        set {
            videoIO.videoOrientation = newValue
        }
    }
    #endif

    /// Specifies the frame rate of a device capture.
    public var frameRate: Float64 {
        get {
            return videoIO.frameRate
        }
        set {
            videoIO.frameRate = newValue
        }
    }

    public weak var delegate: (any IOMixerDelegate)?

    public private(set) var isRunning = false

    private(set) lazy var audioIO = {
        var audioIO = IOAudioUnit()
        audioIO.mixer = self
        return audioIO
    }()

    private(set) lazy var videoIO = {
        var videoIO = IOVideoUnit()
        videoIO.mixer = self
        return videoIO
    }()

    private(set) lazy var session = {
        var session = IOCaptureSession()
        session.delegate = self
        return session
    }()

    private var streams: [any IOStream] = []

    /// Creates a new instance.
    public init() {
    }

    /// Attaches the camera device.
    @available(tvOS 17.0, *)
    public func attachCamera(_ device: AVCaptureDevice?, track: UInt8 = 0, configuration: IOVideoCaptureConfigurationBlock? = nil) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            do {
                try videoIO.attachCamera(track, device: device, configuration: configuration)
                continuation.resume()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Returns the IOVideoCaptureUnit by track.
    @available(tvOS 17.0, *)
    public func videoCapture(for track: UInt8) -> IOVideoCaptureUnit? {
        return videoIO.capture(for: track)
    }

    #if os(iOS) || os(macOS) || os(tvOS)
    /// Attaches the audio device.
    ///
    /// You can perform multi-microphone capture by specifying as follows on macOS. Unfortunately, it seems that only one microphone is available on iOS.
    /// ```
    /// FeatureUtil.setEnabled(for: .multiTrackAudioMixing, isEnabled: true)
    /// var audios = AVCaptureDevice.devices(for: .audio)
    /// if let device = audios.removeFirst() {
    ///    stream.attachAudio(device, track: 0)
    /// }
    /// if let device = audios.removeFirst() {
    ///    stream.attachAudio(device, track: 1)
    /// }
    /// ```
    @available(tvOS 17.0, *)
    public func attachAudio(_ device: AVCaptureDevice?, track: UInt8 = 0, configuration: IOAudioCaptureConfigurationBlock? = nil) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            do {
                try audioIO.attachAudio(track, device: device, configuration: configuration)
                continuation.resume()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Returns the IOAudioCaptureUnit by track.
    @available(tvOS 17.0, *)
    public func audioCapture(for track: UInt8) -> IOAudioCaptureUnit? {
        return audioIO.capture(for: track)
    }
    #endif

    /// Appends a CMSampleBuffer.
    /// - Parameters:
    ///   - sampleBuffer:The sample buffer to append.
    ///   - track: Track number used for mixing
    public func append(_ sampleBuffer: CMSampleBuffer, track: UInt8 = 0) {
        switch sampleBuffer.formatDescription?.mediaType {
        case .audio?:
            audioIO.append(track, buffer: sampleBuffer)
        case .video?:
            videoIO.append(track, buffer: sampleBuffer)
        default:
            break
        }
    }

    /// Appends an AVAudioBuffer.
    /// - Parameters:
    ///   - audioBuffer:The audio buffer to append.
    ///   - when: The audio time to append.
    ///   - track: Track number used for mixing.
    public func append(_ audioBuffer: AVAudioBuffer, when: AVAudioTime, track: UInt8 = 0) {
        audioIO.append(track, buffer: audioBuffer, when: when)
    }

    /// Registers a video effect.
    public func registerVideoEffect(_ effect: VideoEffect) -> Bool {
        videoIO.registerEffect(effect)
    }

    /// Unregisters a video effect.
    public func unregisterVideoEffect(_ effect: VideoEffect) -> Bool {
        videoIO.unregisterEffect(effect)
    }

    /// Configurations for the AVCaptureSession.
    @available(tvOS 17.0, *)
    public func configuration(_ lambda: (_ session: AVCaptureSession) throws -> Void) rethrows {
        try session.configuration(lambda)
    }

    #if os(iOS) || os(tvOS) || os(visionOS)
    func setBackgroundMode(_ background: Bool) {
        guard #available(tvOS 17.0, *) else {
            return
        }
        if background {
            videoIO.setBackgroundMode(background)
        } else {
            videoIO.setBackgroundMode(background)
            session.startRunningIfNeeded()
        }
    }
    #endif

    /// Adds a stream.
    public func addStream(_ stream: some IOStream) {
        guard !streams.contains(where: { $0 === stream }) else {
            return
        }
        streams.append(stream)
    }

    /// Removes a stream.
    public func removeStream(_ stream: some IOStream) {
        if let index = streams.firstIndex(where: { $0 === stream }) {
            streams.remove(at: index)
        }
    }

    #if os(iOS) || os(tvOS) || os(visionOS)
    @objc
    private func didEnterBackground(_ notification: Notification) {
        // Require main thread. Otherwise the microphone cannot be used in the background.
        setBackgroundMode(true)
    }

    @objc
    private func willEnterForeground(_ notification: Notification) {
        setBackgroundMode(false)
    }
    #endif
}

extension IOMixer: Runner {
    // MARK: Running
    public func startRunning() {
        guard !isRunning else {
            return
        }
        isRunning = true
    }

    public func stopRunning() {
        guard isRunning else {
            return
        }
        isRunning = false
    }
}

extension IOMixer: IOCaptureSessionDelegate {
    // MARK: IOCaptureSessionDelegate
    @available(tvOS 17.0, *)
    func captureSession(_ capture: IOCaptureSession, sessionRuntimeError session: AVCaptureSession, error: AVError) {
        #if os(iOS) || os(tvOS) || os(macOS)
        switch error.code {
        case .unsupportedDeviceActiveFormat:
            guard let device = error.device, let format = device.videoFormat(
                width: session.sessionPreset.width ?? 1024,
                height: session.sessionPreset.height ?? 1024,
                frameRate: videoIO.frameRate,
                isMultiCamSupported: capture.isMultiCamSessionEnabled
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
                capture.startRunningIfNeeded()
            } catch {
                logger.warn(error)
            }
        default:
            break
        }
        #endif
    }

    #if os(iOS) || os(tvOS) || os(visionOS)
    @available(tvOS 17.0, *)
    func captureSession(_ _: IOCaptureSession, sessionWasInterrupted session: AVCaptureSession, reason: AVCaptureSession.InterruptionReason?) {
        delegate?.mixer(self, sessionWasInterrupted: session, reason: reason)
    }

    @available(tvOS 17.0, *)
    func captureSession(_ _: IOCaptureSession, sessionInterruptionEnded session: AVCaptureSession) {
        delegate?.mixer(self, sessionInterruptionEnded: session)
    }
    #endif
}

extension IOMixer: IOAudioUnitDelegate {
    // MARK: IOAudioUnitDelegate
    func audioUnit(_ audioUnit: IOAudioUnit, track: UInt8, didInput audioBuffer: AVAudioBuffer, when: AVAudioTime) {
        delegate?.mixer(self, track: track, didInput: audioBuffer, when: when)
    }

    func audioUnit(_ audioUnit: IOAudioUnit, errorOccurred error: IOAudioUnitError) {
        delegate?.mixer(self, audioErrorOccurred: error)
    }

    func audioUnit(_ audioUnit: IOAudioUnit, didOutput audioBuffer: AVAudioPCMBuffer, when: AVAudioTime) {
        for stream in streams {
            Task {
                await stream.append(audioBuffer, when: when)
            }
        }
    }
}

extension IOMixer: IOVideoUnitDelegate {
    // MARK: IOVideoUnitDelegate
    func videoUnit(_ videoUnit: IOVideoUnit, track: UInt8, didInput sampleBuffer: CMSampleBuffer) {
        delegate?.mixer(self, track: track, didInput: sampleBuffer)
    }

    func videoUnit(_ videoUnit: IOVideoUnit, didOutput sampleBuffer: CMSampleBuffer) {
        for stream in streams {
            Task {
                await stream.append(sampleBuffer)
            }
        }
    }
}
