import AVFoundation
import CoreImage
import CoreMedia
#if canImport(SwiftPMSupport)
import SwiftPMSupport
#endif
#if canImport(UIKit)
import UIKit
#endif

/// The interface an IOStream uses to inform its delegate.
public protocol IOStreamDelegate: AnyObject {
    /// Tells the receiver to an audio packet incoming.
    func stream(_ stream: IOStream, didOutput audio: AVAudioBuffer, when: AVAudioTime)
    /// Tells the receiver to a video incoming.
    func stream(_ stream: IOStream, didOutput video: CMSampleBuffer)
    /// Tells the receiver to video error occured.
    func stream(_ stream: IOStream, videoErrorOccurred error: IOVideoUnitError)
    /// Tells the receiver to audio error occured.
    func stream(_ stream: IOStream, audioErrorOccurred error: IOAudioUnitError)
    /// Tells the receiver that the ready state will change.
    func stream(_ stream: IOStream, willChangeReadyState state: IOStream.ReadyState)
    /// Tells the receiver that the ready state did change.
    func stream(_ stream: IOStream, didChangeReadyState state: IOStream.ReadyState)
    #if os(iOS) || os(tvOS) || os(visionOS)
    /// Tells the receiver to session was interrupted.
    @available(tvOS 17.0, *)
    func stream(_ stream: IOStream, sessionWasInterrupted session: AVCaptureSession, reason: AVCaptureSession.InterruptionReason?)
    /// Tells the receiver to session interrupted ended.
    @available(tvOS 17.0, *)
    func stream(_ stream: IOStream, sessionInterruptionEnded session: AVCaptureSession)
    #endif
}

/// The `IOStream` class is the foundation of a RTMPStream.
open class IOStream: NSObject {
    /// The AVAudioEngine shared instance holder.
    static let audioEngineHolder: InstanceHolder<AVAudioEngine> = .init {
        return AVAudioEngine()
    }

    /// The enumeration defines the state a ReadyState NetStream is in.
    public enum ReadyState: Equatable {
        public static func == (lhs: IOStream.ReadyState, rhs: IOStream.ReadyState) -> Bool {
            return lhs.rawValue == rhs.rawValue
        }

        /// NetStream has been created.
        case initialized
        /// NetStream waiting for new method.
        case open
        /// NetStream play() has been called.
        case play
        /// NetStream play and server was accepted as playing
        case playing
        /// NetStream publish() has been called
        case publish
        /// NetStream publish and server accpted as publising.
        case publishing(muxer: any IOMuxer)
        /// NetStream close() has been called.
        case closed

        var rawValue: UInt8 {
            switch self {
            case .initialized:
                return 0
            case .open:
                return 1
            case .play:
                return 2
            case .playing:
                return 3
            case .publish:
                return 4
            case .publishing:
                return 5
            case .closed:
                return 6
            }
        }
    }

    /// The lockQueue.
    public let lockQueue: DispatchQueue = .init(label: "com.haishinkit.HaishinKit.IOStream.lock", qos: .userInitiated)

    /// Specifies the adaptibe bitrate strategy.
    public var bitrateStrategy: any IOStreamBitRateStrategyConvertible = IOStreamBitRateStrategy.shared {
        didSet {
            bitrateStrategy.stream = self
            bitrateStrategy.setUp()
        }
    }

    /// Specifies the audio monitoring enabled or not.
    public var isMonitoringEnabled: Bool {
        get {
            mixer.audioIO.isMonitoringEnabled
        }
        set {
            mixer.audioIO.isMonitoringEnabled = newValue
        }
    }

    /// Specifies the context object.
    public var context: CIContext {
        get {
            mixer.videoIO.context
        }
        set {
            mixer.videoIO.context = newValue
        }
    }

    #if os(iOS) || os(macOS) || os(tvOS)
    /// Specifiet the device torch indicating wheter the turn on(TRUE) or not(FALSE).
    public var torch: Bool {
        get {
            return lockQueue.sync { self.mixer.videoIO.torch }
        }
        set {
            lockQueue.async {
                self.mixer.videoIO.torch = newValue
            }
        }
    }

    /// Specifies the frame rate of a device capture.
    public var frameRate: Float64 {
        get {
            return lockQueue.sync { self.mixer.videoIO.frameRate }
        }
        set {
            lockQueue.async {
                self.mixer.videoIO.frameRate = newValue
            }
        }
    }

    #if os(iOS) || os(tvOS)
    /// Specifies the AVCaptureMultiCamSession enabled.
    /// Warning: If there is a possibility of using multiple cameras, please set it to true initially.
    @available(tvOS 17.0, iOS 13.0, *)
    public var isMultiCamSessionEnabled: Bool {
        get {
            return mixer.session.isMultiCamSessionEnabled
        }
        set {
            mixer.session.isMultiCamSessionEnabled = newValue
        }
    }
    #endif

    /// Specifies the sessionPreset for the AVCaptureSession.
    @available(tvOS 17.0, *)
    public var sessionPreset: AVCaptureSession.Preset {
        get {
            return lockQueue.sync { self.mixer.session.sessionPreset }
        }
        set {
            lockQueue.async {
                self.mixer.session.sessionPreset = newValue
            }
        }
    }
    #endif

    #if os(iOS) || os(macOS)
    /// Specifies the video orientation for stream.
    public var videoOrientation: AVCaptureVideoOrientation {
        get {
            mixer.videoIO.videoOrientation
        }
        set {
            mixer.videoIO.videoOrientation = newValue
        }
    }
    #endif

    /// Specifies the video mixer settings..
    public var videoMixerSettings: IOVideoMixerSettings {
        get {
            mixer.videoIO.mixerSettings
        }
        set {
            mixer.videoIO.mixerSettings = newValue
        }
    }

    /// Specifies the hasAudio indicies whether no signal audio or not.
    public var hasAudio: Bool {
        get {
            !mixer.audioIO.muted
        }
        set {
            mixer.audioIO.muted = !newValue
        }
    }

    /// Specifies the hasVideo indicies whether freeze video signal or not.
    public var hasVideo: Bool {
        get {
            !mixer.videoIO.muted
        }
        set {
            mixer.videoIO.muted = !newValue
        }
    }

    /// Specifies the audio compression properties.
    public var audioSettings: AudioCodecSettings {
        get {
            mixer.audioIO.settings
        }
        set {
            mixer.audioIO.settings = newValue
        }
    }

    /// Specifies the video compression properties.
    public var videoSettings: VideoCodecSettings {
        get {
            mixer.videoIO.settings
        }
        set {
            mixer.videoIO.settings = newValue
        }
    }

    /// The video input format.
    public var videoInputFormat: CMVideoFormatDescription? {
        return mixer.videoIO.inputFormat
    }

    /// The audio input format.
    public var audioInputFormat: AVAudioFormat? {
        return mixer.audioIO.inputFormat
    }

    /// The isRecording value that indicates whether the recorder is recording.
    public var isRecording: Bool {
        return mixer.recorder.isRunning.value
    }

    /// Specifies the controls sound.
    public var soundTransform: SoundTransform {
        get {
            telly.soundTransform
        }
        set {
            telly.soundTransform = newValue
        }
    }

    /// The number of frames per second being displayed.
    @objc public internal(set) dynamic var currentFPS: UInt16 = 0

    /// Specifies the delegate.
    public weak var delegate: (any IOStreamDelegate)?

    /// Specifies the drawable.
    public var drawable: (any IOStreamView)? {
        get {
            lockQueue.sync { mixer.videoIO.drawable }
        }
        set {
            lockQueue.async {
                self.mixer.videoIO.drawable = newValue
                guard #available(tvOS 17.0, *) else {
                    return
                }
                if newValue != nil && self.mixer.videoIO.hasDevice {
                    self.mixer.session.startRunning()
                }
            }
        }
    }

    /// The current state of the stream.
    public var readyState: ReadyState = .initialized {
        willSet {
            guard readyState != newValue else {
                return
            }
            delegate?.stream(self, willChangeReadyState: readyState)
            readyStateWillChange(to: newValue)
        }
        didSet {
            guard readyState != oldValue else {
                return
            }
            readyStateDidChange(to: readyState)
            delegate?.stream(self, didChangeReadyState: readyState)
        }
    }

    private(set) lazy var mixer = {
        let mixer = IOMixer()
        mixer.delegate = self
        return mixer
    }()

    private lazy var telly = {
        let telly = IOTellyUnit()
        telly.delegate = self
        return telly
    }()

    /// Creates a NetStream object.
    override public init() {
        super.init()
        #if os(iOS) || os(tvOS) || os(visionOS)
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground(_:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)
        #endif
    }

    /// Attaches the camera object.
    @available(tvOS 17.0, *)
    public func attachCamera(_ device: AVCaptureDevice?, channel: UInt8 = 0, configuration: IOVideoCaptureConfigurationBlock? = nil) {
        lockQueue.async {
            do {
                try self.mixer.videoIO.attachCamera(device, channel: channel, configuration: configuration)
            } catch {
                configuration?(nil, IOVideoUnitError.failedToAttach(error: error))
            }
        }
    }

    /// Returns the IOVideoCaptureUnit by channel.
    @available(tvOS 17.0, *)
    public func videoCapture(for channel: UInt8) -> IOVideoCaptureUnit? {
        return mixer.videoIO.lockQueue.sync {
            return self.mixer.videoIO.capture(for: channel)
        }
    }

    #if os(iOS) || os(macOS) || os(tvOS)
    /// Attaches the audio capture object.
    /// - Warning: This method can't use appendSampleBuffer at the same time.
    @available(tvOS 17.0, *)
    public func attachAudio(_ device: AVCaptureDevice?, automaticallyConfiguresApplicationAudioSession: Bool = false, onError: ((_ error: any Error) -> Void)? = nil) {
        lockQueue.async {
            do {
                try self.mixer.audioIO.attachAudio(device, automaticallyConfiguresApplicationAudioSession: automaticallyConfiguresApplicationAudioSession)
            } catch {
                onError?(error)
            }
        }
    }
    #endif

    /// Append a CMSampleBuffer.
    /// - Warning: This method can't use attachCamera or attachAudio method at the same time.
    public func append(_ sampleBuffer: CMSampleBuffer, channel: UInt8 = 0) {
        switch sampleBuffer.formatDescription?.mediaType {
        case .audio?:
            mixer.audioIO.lockQueue.async {
                self.mixer.audioIO.append(sampleBuffer, channel: channel)
            }
        case .video?:
            mixer.videoIO.lockQueue.async {
                self.mixer.videoIO.append(sampleBuffer, channel: channel)
            }
        default:
            break
        }
    }

    /// Append an AVAudioBuffer.
    /// - Warning: This method can't use attachAudio method at the same time.
    public func append(_ audioBuffer: AVAudioBuffer, when: AVAudioTime, channel: UInt8 = 0) {
        mixer.audioIO.lockQueue.async {
            self.mixer.audioIO.append(audioBuffer, when: when, channel: channel)
        }
    }

    /// Register a video effect.
    public func registerVideoEffect(_ effect: VideoEffect) -> Bool {
        mixer.videoIO.lockQueue.sync {
            self.mixer.videoIO.registerEffect(effect)
        }
    }

    /// Unregister a video effect.
    public func unregisterVideoEffect(_ effect: VideoEffect) -> Bool {
        mixer.videoIO.lockQueue.sync {
            self.mixer.videoIO.unregisterEffect(effect)
        }
    }

    /// Starts recording.
    public func startRecording(_ delegate: any IOStreamRecorderDelegate, settings: [AVMediaType: [String: Any]] = IOStreamRecorder.defaultOutputSettings) {
        mixer.recorder.delegate = delegate
        mixer.recorder.outputSettings = settings
        mixer.recorder.startRunning()
    }

    /// Stop recording.
    public func stopRecording() {
        mixer.recorder.stopRunning()
    }

    /// A handler that receives stream readyState will update.
    /// - Warning: Please do not call this method yourself.
    open func readyStateWillChange(to readyState: ReadyState) {
        switch self.readyState {
        case .playing:
            mixer.stopRunning()
        case .publishing:
            mixer.stopRunning()
        default:
            break
        }
    }

    /// A handler that receives stream readyState updated.
    /// - Warning: Please do not call this method yourself.
    open func readyStateDidChange(to readyState: ReadyState) {
        switch readyState {
        case .play:
            audioSettings.format = .pcm
            mixer.muxer = telly
            mixer.startRunning()
        case .publish:
            mixer.session.startRunning()
        case .publishing(let muxer):
            mixer.muxer = muxer
            mixer.startRunning()
        default:
            break
        }
    }

    #if os(iOS) || os(tvOS) || os(visionOS)
    @objc
    private func didEnterBackground(_ notification: Notification) {
        // Require main thread. Otherwise the microphone cannot be used in the background.
        mixer.setBackgroundMode(true)
    }

    @objc
    private func willEnterForeground(_ notification: Notification) {
        lockQueue.async {
            self.mixer.setBackgroundMode(false)
        }
    }
    #endif
}

extension IOStream: IOMixerDelegate {
    // MARK: IOMixerDelegate
    func mixer(_ mixer: IOMixer, didOutput video: CMSampleBuffer) {
        delegate?.stream(self, didOutput: video)
    }

    func mixer(_ mixer: IOMixer, didOutput audio: AVAudioPCMBuffer, when: AVAudioTime) {
        delegate?.stream(self, didOutput: audio, when: when)
    }

    func mixer(_ mixer: IOMixer, audioErrorOccurred error: IOAudioUnitError) {
        delegate?.stream(self, audioErrorOccurred: error)
    }

    func mixer(_ mixer: IOMixer, videoErrorOccurred error: IOVideoUnitError) {
        delegate?.stream(self, videoErrorOccurred: error)
    }

    #if os(iOS) || os(tvOS) || os(visionOS)
    @available(tvOS 17.0, *)
    func mixer(_ mixer: IOMixer, sessionWasInterrupted session: AVCaptureSession, reason: AVCaptureSession.InterruptionReason?) {
        delegate?.stream(self, sessionWasInterrupted: session, reason: reason)
    }

    @available(tvOS 17.0, *)
    func mixer(_ mixer: IOMixer, sessionInterruptionEnded session: AVCaptureSession) {
        delegate?.stream(self, sessionInterruptionEnded: session)
    }
    #endif
}

extension IOStream: IOTellyUnitDelegate {
    // MARK: IOTellyUnitDelegate
    func tellyUnit(_ tellyUnit: IOTellyUnit, dequeue sampleBuffer: CMSampleBuffer) {
        mixer.videoIO.drawable?.enqueue(sampleBuffer)
    }

    func tellyUnit(_ tellyUnit: IOTellyUnit, didBufferingChanged: Bool) {
    }

    func tellyUnit(_ tellyUnit: IOTellyUnit, didSetAudioFormat audioFormat: AVAudioFormat?) {
        guard let audioEngine = mixer.audioEngine else {
            return
        }
        nstry({
            if let audioFormat {
                audioEngine.attach(tellyUnit.playerNode)
                audioEngine.connect(tellyUnit.playerNode, to: audioEngine.mainMixerNode, format: audioFormat)
                if !audioEngine.isRunning {
                    try? audioEngine.start()
                }
            } else {
                audioEngine.detach(tellyUnit.playerNode)
                audioEngine.disconnectNodeInput(tellyUnit.playerNode)
                if audioEngine.isRunning {
                    audioEngine.stop()
                }
            }
        }, { exeption in
            logger.warn(exeption)
        })
    }
}
