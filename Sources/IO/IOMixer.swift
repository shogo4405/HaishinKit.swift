import AVFoundation
import Combine

#if canImport(SwiftPMSupport)
import SwiftPMSupport
#endif

#if canImport(UIKit)
import UIKit
#endif

/// An object that mixies audio and video for streaming.
public final actor IOMixer {
    static let defaultFrameRate: Float64 = 30

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
        videoIO.torch
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
    public var audioMixerSettings: IOAudioMixerSettings {
        audioIO.mixerSettings
    }

    /// The video mixer settings.
    public var videoMixerSettings: IOVideoMixerSettings {
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

    #if os(iOS) || os(macOS)
    /// Specifies the video orientation for stream.
    public var videoOrientation: AVCaptureVideoOrientation {
        videoIO.videoOrientation
    }
    #endif

    public private(set) var isRunning = false

    private var streams: [any IOStream] = []
    private lazy var audioIO = IOAudioUnit(session)
    private lazy var videoIO = IOVideoUnit(session)
    private lazy var session = IOCaptureSession()
    private var cancellables: Set<AnyCancellable> = []

    /// Creates a new instance.
    public init() {
        Task {
            await startRunning()
        }
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

    /// Specifies the device torch indicating wheter the turn on(TRUE) or not(FALSE).
    public func setTorchEnabled(_ torchEnabled: Bool) {
        videoIO.torch = torchEnabled
    }

    /// Specifies the sessionPreset for the AVCaptureSession.
    public func setSessionPreset(_ sessionPreset: AVCaptureSession.Preset) {
        session.sessionPreset = sessionPreset
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

    /// Specifies the video orientation for stream.
    public func setVideoOrientation(_ videoOrientation: AVCaptureVideoOrientation) {
        videoIO.videoOrientation = videoOrientation
    }

    /// Specifies the video mixier settings.
    public func setVideoMixerSettings(_ settings: IOVideoMixerSettings) {
        videoIO.mixerSettings = settings
    }

    /// Specifies the frame rate of a device capture.
    public func setFrameRate(_ frameRate: Float64) {
        videoIO.frameRate = frameRate
    }

    /// Specifies the audio mixer settings.
    public func setAudioMixerSettings(_ settings: IOAudioMixerSettings) {
        audioIO.mixerSettings = settings
    }

    /// Specifies the audio monitoring enabled or not.
    public func setMonitoringEnabled(_ monitoringEnabled: Bool) {
        audioIO.isMonitoringEnabled = monitoringEnabled
    }

    #if os(iOS) || os(tvOS)
    /// Specifies the AVCaptureMultiCamSession enabled.
    /// Warning: If there is a possibility of using multiple cameras, please set it to true initially.
    public func setMultiCamSessionEnabled(_ multiCamSessionEnabled: Bool) {
        session.isMultiCamSessionEnabled = multiCamSessionEnabled
    }
    #endif

    /// Specifies the feature to mix multiple audio tracks. For example, it is possible to mix .appAudio and .micAudio from ReplayKit.
    /// Warning: If there is a possibility of this feature, please set it to true initially.
    public func setMultiTrackAudioMixingEnabled(_ multiTrackAudioMixingEnabled: Bool) {
        audioIO.isMultiTrackAudioMixingEnabled = multiTrackAudioMixingEnabled
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
    @available(tvOS 17.0, *)
    public func configuration(_ lambda: (_ session: AVCaptureSession) throws -> Void) rethrows {
        try session.configuration(lambda)
    }

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
}

extension IOMixer: AsyncRunner {
    // MARK: AsyncRunner
    public func startRunning() {
        guard !isRunning else {
            return
        }
        isRunning = true
        Task {
            for await inputs in videoIO.inputs where isRunning {
                Task { @ScreenActor in
                    screen.append(inputs.0, buffer: inputs.1)
                }
            }
        }
        Task {
            for await video in videoIO.output where isRunning {
                for stream in streams {
                    await stream.append(video)
                }
            }
        }
        Task {
            for await audio in audioIO.output where isRunning {
                for stream in self.streams {
                    await stream.append(audio.0, when: audio.1)
                }
            }
        }
        Task { @ScreenActor in
            for await _ in AsyncDisplayLink.updateFrames where await isRunning {
                guard let buffer = screen.makeSampleBuffer() else {
                    return
                }
                for stream in await streams {
                    await stream.append(buffer)
                }
            }
        }
        #if os(iOS) || os(tvOS) || os(visionOS)
        NotificationCenter
            .Publisher(center: .default, name: UIApplication.didEnterBackgroundNotification, object: nil)
            .sink { _ in
                Task {
                    self.setBackgroundMode(true)
                }
            }
            .store(in: &cancellables)
        NotificationCenter
            .Publisher(center: .default, name: UIApplication.willEnterForegroundNotification, object: nil)
            .sink { _ in
                Task {
                    self.setBackgroundMode(false)
                }
            }
            .store(in: &cancellables)
        #endif
    }

    public func stopRunning() {
        guard isRunning else {
            return
        }
        isRunning = false
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }
}
