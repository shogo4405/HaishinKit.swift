@preconcurrency import AVFoundation
import Combine

#if canImport(UIKit)
import UIKit
#endif

/// An actor that mixies audio and video for streaming.
public final actor MediaMixer {
    static let defaultFrameRate: Float64 = 30

    /// The error domain codes.
    public enum Error: Swift.Error {
        /// The mixer failed to failed to attach device.
        case failedToAttach(_ error: any Swift.Error)
        /// The mixer missing a device of track.
        case deviceNotFound
    }

    /// The offscreen rendering object.
    @ScreenActor
    public private(set) lazy var screen = Screen()

    #if os(iOS) || os(tvOS)
    /// The AVCaptureMultiCamSession enabled.
    @available(tvOS 17.0, *)
    public var isMultiCamSessionEnabled: Bool {
        session.isMultiCamSessionEnabled
    }
    #endif

    #if os(iOS) || os(macOS) || os(tvOS)
    /// The device torch indicating wheter the turn on(TRUE) or not(FALSE).
    public var isTorchEnabled: Bool {
        videoIO.isTorchEnabled
    }

    /// The feature to mix multiple audio tracks. For example, it is possible to mix .appAudio and .micAudio from ReplayKit.
    public var isMultiTrackAudioMixingEnabled: Bool {
        audioIO.isMultiTrackAudioMixingEnabled
    }

    /// The sessionPreset for the AVCaptureSession.
    @available(tvOS 17.0, *)
    public var sessionPreset: AVCaptureSession.Preset {
        session.sessionPreset
    }
    #endif

    /// The audio monitoring enabled or not.
    public var isMonitoringEnabled: Bool {
        audioIO.isMonitoringEnabled
    }

    /// The audio mixer settings.
    public var audioMixerSettings: AudioMixerSettings {
        audioIO.mixerSettings
    }

    /// The video mixer settings.
    public var videoMixerSettings: VideoMixerSettings {
        videoIO.mixerSettings
    }

    /// The audio input formats.
    public var audioInputFormats: [UInt8: AVAudioFormat] {
        audioIO.inputFormats
    }

    /// The video input formats.
    public var videoInputFormats: [UInt8: CMFormatDescription] {
        videoIO.inputFormats
    }

    /// The frame rate of a device capture.
    public var frameRate: Float64 {
        videoIO.frameRate
    }

    /// The capture session is in a running state or not.
    @available(tvOS 17.0, *)
    public var isCapturing: Bool {
        session.isRunning
    }

    /// The interrupts events is occured or not.
    public var isInterputted: AsyncStream<Bool> {
        session.isInturreped
    }

    #if os(iOS) || os(macOS)
    /// The video orientation for stream.
    public var videoOrientation: AVCaptureVideoOrientation {
        videoIO.videoOrientation
    }
    #endif

    public private(set) var isRunning = false
    private var outputs: [any MediaMixerOutput] = []
    @MainActor
    private var cancellables: Set<AnyCancellable> = []
    private let useManualCapture: Bool
    private lazy var audioIO = AudioCaptureUnit(session)
    private lazy var videoIO = VideoCaptureUnit(session)
    private lazy var session = CaptureSession()
    @ScreenActor
    private lazy var displayLink = DisplayLinkChoreographer()

    #if os(iOS) || os(tvOS)
    /// Creates a new instance.
    ///
    /// - Parameters:
    ///   - multiCamSessionEnabled: Specifies the AVCaptureMultiCamSession enabled.
    ///   - multiTrackAudioMixingEnabled: Specifies the feature to mix multiple audio tracks. For example, it is possible to mix .appAudio and .micAudio from ReplayKit.
    ///   - useManualCapture: Specifies whether to start capturing manually. #1642
    public init(
        multiCamSessionEnabled: Bool = true,
        multiTrackAudioMixingEnabled: Bool = false,
        useManualCapture: Bool = false
    ) {
        self.useManualCapture = useManualCapture
        Task {
            await _init(
                multiCamSessionEnabled: multiCamSessionEnabled,
                multiTrackAudioMixingEnabled: multiTrackAudioMixingEnabled,
                useManualCapture: useManualCapture
            )
        }
    }

    private func _init(
        multiCamSessionEnabled: Bool,
        multiTrackAudioMixingEnabled: Bool,
        useManualCapture: Bool
    ) async {
        session.isMultiCamSessionEnabled = multiCamSessionEnabled
        audioIO.isMultiTrackAudioMixingEnabled = multiTrackAudioMixingEnabled
        if !useManualCapture {
            startRunning()
        }
    }

    #else
    /// Creates a new instance.
    ///
    /// - Parameters:
    ///   - multiTrackAudioMixingEnabled: Specifies the feature to mix multiple audio tracks. For example, it is possible to mix .appAudio and .micAudio from ReplayKit.
    ///   - useManualCapture: Specifies whether to start capturing manually. #1642
    public init(
        multiTrackAudioMixingEnabled: Bool = false,
        useManualCapture: Bool = false
    ) {
        self.useManualCapture = useManualCapture
        Task {
            await _init(
                multiTrackAudioMixingEnabled: multiTrackAudioMixingEnabled,
                useManualCapture: useManualCapture
            )
        }
    }

    private func _init(
        multiTrackAudioMixingEnabled: Bool,
        useManualCapture: Bool
    ) async {
        audioIO.isMultiTrackAudioMixingEnabled = multiTrackAudioMixingEnabled
        if !useManualCapture {
            startRunning()
        }
    }
    #endif

    /// Attaches a video device.
    ///
    /// If you want to use the multi-camera feature, please make create a MediaMixer with a multiCamSession mode for iOS.
    /// let mixer = MediaMixer(multiCamSessionEnabled: true, multiTrackAudioMixingEnabled: false)
    ///
    @available(tvOS 17.0, *)
    public func attachVideo(_ device: AVCaptureDevice?, track: UInt8 = 0, configuration: VideoDeviceConfigurationBlock? = nil) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            do {
                try videoIO.attachVideo(track, device: device, configuration: configuration)
                continuation.resume()
            } catch {
                continuation.resume(throwing: Error.failedToAttach(error))
            }
        }
    }

    /// Configurations for a video device.
    @available(tvOS 17.0, *)
    public func configuration(video track: UInt8, configuration: VideoDeviceConfigurationBlock) throws {
        guard let unit = videoIO.devices[track] else {
            throw Error.deviceNotFound
        }
        try configuration(unit)
    }

    #if os(iOS) || os(macOS) || os(tvOS)
    /// Attaches an audio device.
    ///
    /// - Attention: You can perform multi-microphone capture by specifying as follows on macOS. Unfortunately, it seems that only one microphone is available on iOS.
    ///
    /// ```
    /// let mixer = MediaMixer(multiCamSessionEnabled: false, multiTrackAudioMixingEnabled: true)
    ///
    /// var audios = AVCaptureDevice.devices(for: .audio)
    /// if let device = audios.removeFirst() {
    ///    mixer.attachAudio(device, track: 0)
    /// }
    /// if let device = audios.removeFirst() {
    ///    mixer.attachAudio(device, track: 1)
    /// }
    /// ```
    @available(tvOS 17.0, *)
    public func attachAudio(_ device: AVCaptureDevice?, track: UInt8 = 0, configuration: AudioDeviceConfigurationBlock? = nil) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            do {
                try audioIO.attachAudio(track, device: device, configuration: configuration)
                continuation.resume()
            } catch {
                continuation.resume(throwing: Error.failedToAttach(error))
            }
        }
    }

    /// Configurations for an audio device.
    @available(tvOS 17.0, *)
    public func configuration(audio track: UInt8, configuration: AudioDeviceConfigurationBlock) throws {
        guard let unit = audioIO.devices[track] else {
            throw Error.deviceNotFound
        }
        try configuration(unit)
    }

    /// Sets the device torch indicating wheter the turn on(TRUE) or not(FALSE).
    public func setTorchEnabled(_ torchEnabled: Bool) {
        videoIO.isTorchEnabled = torchEnabled
    }

    /// Sets the sessionPreset for the AVCaptureSession.
    @available(tvOS 17.0, *)
    public func setSessionPreset(_ sessionPreset: AVCaptureSession.Preset) {
        session.sessionPreset = sessionPreset
    }
    #endif

    #if os(iOS) || os(macOS)
    /// Sets the video orientation for stream.
    public func setVideoOrientation(_ videoOrientation: AVCaptureVideoOrientation) {
        videoIO.videoOrientation = videoOrientation
        // https://github.com/shogo4405/HaishinKit.swift/issues/190
        if videoIO.isTorchEnabled {
            videoIO.isTorchEnabled = true
        }
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

    /// Sets the video mixier settings.
    public func setVideoMixerSettings(_ settings: VideoMixerSettings) {
        let mode = self.videoMixerSettings.mode
        if mode != settings.mode {
            setVideoRenderingMode(settings.mode)
        }
        videoIO.mixerSettings = settings
        Task { @ScreenActor in
            screen.videoTrackScreenObject.track = settings.mainTrack
        }
    }

    /// Sets the frame rate of a device capture.
    public func setFrameRate(_ frameRate: Float64) {
        videoIO.frameRate = frameRate
        Task { @ScreenActor in
            displayLink.preferredFramesPerSecond = Int(frameRate)
        }
    }

    /// Sets the audio mixer settings.
    public func setAudioMixerSettings(_ settings: AudioMixerSettings) {
        audioIO.mixerSettings = settings
    }

    /// Sets the audio monitoring enabled or not.
    public func setMonitoringEnabled(_ monitoringEnabled: Bool) {
        audioIO.isMonitoringEnabled = monitoringEnabled
    }

    /// Starts capturing from input devices.
    ///
    /// Internally, it is called either when the view is attached or just before publishing. In other cases, please call this method if you want to manually start the capture.
    @available(tvOS 17.0, *)
    public func startCapturing() {
        session.startRunning()
    }

    /// Stops capturing from input devices.
    @available(tvOS 17.0, *)
    public func stopCapturing() {
        session.stopRunning()
    }

    /// Appends an AVAudioBuffer.
    /// - Parameters:
    ///   - audioBuffer:The audio buffer to append.
    ///   - when: The audio time to append.
    ///   - track: Track number used for mixing.
    public func append(_ audioBuffer: AVAudioBuffer, when: AVAudioTime, track: UInt8 = 0) {
        audioIO.append(track, buffer: audioBuffer, when: when)
    }

    /// Configurations for the AVCaptureSession.
    /// - Attention: Internally, there is no need for developers to call beginConfiguration() and func commitConfiguration() as they are called automatically.
    @available(tvOS 17.0, *)
    public func configuration(_ lambda: @Sendable (_ session: AVCaptureSession) throws -> Void) rethrows {
        try session.configuration(lambda)
    }

    /// Adds an output observer.
    public func addOutput(_ output: some MediaMixerOutput) {
        guard !outputs.contains(where: { $0 === output }) else {
            return
        }
        outputs.append(output)
        if #available(tvOS 17.0, *) {
            if !isCapturing && !useManualCapture {
                startCapturing()
            }
        }
    }

    /// Removes an output observer.
    public func removeOutput(_ output: some MediaMixerOutput) {
        if let index = outputs.firstIndex(where: { $0 === output }) {
            outputs.remove(at: index)
        }
    }

    private func setVideoRenderingMode(_ mode: VideoMixerSettings.Mode) {
        guard isRunning else {
            return
        }
        switch mode {
        case .passthrough:
            Task { @ScreenActor in
                displayLink.stopRunning()
            }
        case .offscreen:
            Task { @ScreenActor in
                displayLink.preferredFramesPerSecond = await Int(frameRate)
                displayLink.startRunning()
                for await updateFrame in displayLink.updateFrames {
                    guard let buffer = screen.makeSampleBuffer(updateFrame) else {
                        continue
                    }
                    for output in await self.outputs where await output.videoTrackId == UInt8.max {
                        output.mixer(self, didOutput: buffer)
                    }
                }
            }
        }
    }

    #if os(iOS) || os(tvOS) || os(visionOS)
    private func setBackgroundMode(_ background: Bool) {
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

    @available(tvOS 17.0, *)
    private func sessionRuntimeErrorOccured(_ error: AVError) async {
        switch error.code {
        #if os(iOS) || os(tvOS) || os(visionOS)
        case .mediaServicesWereReset:
            session.startRunningIfNeeded()
        #endif
        #if os(iOS) || os(tvOS) || os(macOS)
        case .unsupportedDeviceActiveFormat:
            guard let device = error.device, let format = device.videoFormat(
                width: session.sessionPreset.width ?? Int32.max,
                height: session.sessionPreset.height ?? Int32.max,
                frameRate: videoIO.frameRate,
                isMultiCamSupported: session.isMultiCamSessionEnabled
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
                session.startRunningIfNeeded()
            } catch {
                logger.warn(error)
            }
        #endif
        default:
            break
        }
    }
}

extension MediaMixer: AsyncRunner {
    // MARK: AsyncRunner
    public func startRunning() {
        guard !isRunning else {
            return
        }
        isRunning = true
        Task {
            for await inputs in videoIO.inputs {
                Task { @ScreenActor in
                    let sampleBuffer = inputs.1
                    screen.append(inputs.0, buffer: sampleBuffer)
                    if await videoMixerSettings.mainTrack == inputs.0 && 0 < screen.targetTimestamp {
                        let diff = ceil((screen.targetTimestamp - sampleBuffer.presentationTimeStamp.seconds) * 10000) / 10000
                        screen.videoCaptureLatency = diff
                    }
                }
                for output in outputs where await output.videoTrackId == inputs.0 {
                    output.mixer(self, didOutput: inputs.1)
                }
            }
        }
        Task {
            for await video in videoIO.output {
                for output in outputs where await output.videoTrackId == UInt8.max {
                    output.mixer(self, didOutput: video)
                }
            }
        }
        Task {
            for await audio in audioIO.output {
                for output in outputs where await output.audioTrackId == UInt8.max {
                    output.mixer(self, didOutput: audio.0, when: audio.1)
                }
            }
        }
        if #available(tvOS 17.0, *) {
            Task {
                for await runtimeError in session.runtimeError {
                    await sessionRuntimeErrorOccured(runtimeError)
                }
            }
        }
        setVideoRenderingMode(videoMixerSettings.mode)
        if useManualCapture {
            session.startRunning()
        }
        #if os(iOS) || os(tvOS) || os(visionOS)
        Task { @MainActor in
            NotificationCenter
                .Publisher(center: .default, name: UIApplication.didEnterBackgroundNotification, object: nil)
                .sink { _ in
                    Task {
                        await self.setBackgroundMode(true)
                    }
                }
                .store(in: &cancellables)
            NotificationCenter
                .Publisher(center: .default, name: UIApplication.willEnterForegroundNotification, object: nil)
                .sink { _ in
                    Task {
                        await self.setBackgroundMode(false)
                    }
                }
                .store(in: &cancellables)
        }
        #endif
    }

    public func stopRunning() {
        guard isRunning else {
            return
        }
        isRunning = false
        if useManualCapture {
            session.stopRunning()
        }
        audioIO.finish()
        videoIO.finish()
        Task { @MainActor in
            cancellables.forEach { $0.cancel() }
            cancellables.removeAll()
        }
        Task { @ScreenActor in
            displayLink.stopRunning()
        }
    }
}
