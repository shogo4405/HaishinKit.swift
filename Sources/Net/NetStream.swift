import AVFoundation
import CoreImage
import CoreMedia
#if canImport(ScreenCaptureKit)
import ScreenCaptureKit
#endif

/// The `NetStream` class is the foundation of a RTMPStream, HTTPStream.
open class NetStream: NSObject {
    /// The lockQueue.
    public let lockQueue: DispatchQueue = {
        let queue = DispatchQueue(label: "com.haishinkit.HaishinKit.NetStream.lock")
        queue.setSpecific(key: queueKey, value: queueValue)
        return queue
    }()

    private static let queueKey = DispatchSpecificKey<UnsafeMutableRawPointer>()
    private static let queueValue = UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1)

    /// The mixer object.
    public private(set) var mixer = IOMixer()

    /// Specifies the context object.
    public var context: CIContext {
        get {
            mixer.videoIO.context
        }
        set {
            mixer.videoIO.context = newValue
        }
    }

    #if os(iOS) || os(macOS)
    /// Specifiet the device torch indicating wheter the turn on(TRUE) or not(FALSE).
    public var torch: Bool {
        get {
            var torch: Bool = false
            lockQueue.sync {
                torch = self.mixer.videoIO.torch
            }
            return torch
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
            var frameRate: Float64 = IOMixer.defaultFrameRate
            lockQueue.sync {
                frameRate = self.mixer.videoIO.frameRate
            }
            return frameRate
        }
        set {
            lockQueue.async {
                self.mixer.videoIO.frameRate = newValue
            }
        }
    }

    /// Specifies the sessionPreset for the AVCaptureSession.
    public var sessionPreset: AVCaptureSession.Preset {
        get {
            var sessionPreset: AVCaptureSession.Preset = .default
            lockQueue.sync {
                sessionPreset = self.mixer.sessionPreset
            }
            return sessionPreset
        }
        set {
            lockQueue.async {
                self.mixer.sessionPreset = newValue
            }
        }
    }

    /// Specifies the video orientation for stream.
    public var videoOrientation: AVCaptureVideoOrientation {
        get {
            mixer.videoIO.videoOrientation
        }
        set {
            mixer.videoIO.videoOrientation = newValue
        }
    }

    /// Specifies the multi camera capture properties.
    public var multiCamCaptureSettings: MultiCamCaptureSetting {
        get {
            mixer.videoIO.multiCamCaptureSettings
        }
        set {
            mixer.videoIO.multiCamCaptureSettings = newValue
        }
    }
    #endif

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
    public var audioSettings: Setting<AudioCodec, AudioCodec.Option> {
        get {
            mixer.audioIO.codec.settings
        }
        set {
            mixer.audioIO.codec.settings = newValue
        }
    }

    /// Specifies the video compression properties.
    public var videoSettings: Setting<VideoCodec, VideoCodec.Option> {
        get {
            mixer.videoIO.codec.settings
        }
        set {
            mixer.videoIO.codec.settings = newValue
        }
    }

    #if os(iOS) || os(macOS)
    /// Attaches the primary camera object.
    /// - Warning: This method can't use appendSampleBuffer at the same time.
    open func attachCamera(_ device: AVCaptureDevice?, onError: ((_ error: Error) -> Void)? = nil) {
        lockQueue.async {
            do {
                try self.mixer.videoIO.attachCamera(device)
            } catch {
                onError?(error)
            }
        }
    }

    /// Attaches the 2ndary camera  object for picture in picture.
    /// - Warning: This method can't use appendSampleBuffer at the same time.
    @available(iOS 13.0, *)
    open func attachMultiCamera(_ device: AVCaptureDevice?, onError: ((_ error: Error) -> Void)? = nil) {
        lockQueue.async {
            do {
                try self.mixer.videoIO.attachMultiCamera(device)
            } catch {
                onError?(error)
            }
        }
    }

    /// Attaches the audio capture object.
    /// - Warning: This method can't use appendSampleBuffer at the same time.
    open func attachAudio(_ device: AVCaptureDevice?, automaticallyConfiguresApplicationAudioSession: Bool = false, onError: ((_ error: Error) -> Void)? = nil) {
        lockQueue.async {
            do {
                try self.mixer.audioIO.attachAudio(device, automaticallyConfiguresApplicationAudioSession: automaticallyConfiguresApplicationAudioSession)
            } catch {
                onError?(error)
            }
        }
    }

    /// Attaches the screen input object.
    @available(iOS, unavailable)
    open func attachScreen(_ input: AVCaptureScreenInput?) {
        lockQueue.async {
            self.mixer.videoIO.attachScreen(input)
        }
    }

    /// Returns the IOVideoCaptureUnit by index.
    public func videoCapture(for index: Int) -> IOVideoCaptureUnit? {
        return mixer.videoIO.lockQueue.sync {
            switch index {
            case 0:
                return self.mixer.videoIO.capture
            case 1:
                return self.mixer.videoIO.multiCamCapture
            default:
                return nil
            }
        }
    }
    #endif

    /// Append a CMSampleBuffer?.
    /// - Warning: This method can't use attachCamera or attachAudio method at the same time.
    open func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer, withType: AVMediaType, options: [NSObject: AnyObject]? = nil) {
        switch withType {
        case .audio:
            mixer.audioIO.lockQueue.async {
                self.mixer.audioIO.appendSampleBuffer(sampleBuffer)
            }
        case .video:
            mixer.videoIO.lockQueue.async {
                self.mixer.videoIO.appendSampleBuffer(sampleBuffer)
            }
        default:
            break
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

    /// Register a audio effect.
    public func registerAudioEffect(_ effect: AudioEffect) -> Bool {
        mixer.audioIO.lockQueue.sync {
            self.mixer.audioIO.registerEffect(effect)
        }
    }

    /// Unregister a audio effect.
    public func unregisterAudioEffect(_ effect: AudioEffect) -> Bool {
        mixer.audioIO.lockQueue.sync {
            self.mixer.audioIO.unregisterEffect(effect)
        }
    }

    /// Starts recording.
    public func startRecording(_ settings: [AVMediaType: [String: Any]]) {
        mixer.recorder.outputSettings = settings
        mixer.recorder.startRunning()
    }

    /// Stop recording.
    public func stopRecording() {
        mixer.recorder.stopRunning()
    }
}

extension NetStream: IOScreenCaptureUnitDelegate {
    // MARK: IOScreenCaptureUnitDelegate
    public func session(_ session: IOScreenCaptureUnit, didOutput pixelBuffer: CVPixelBuffer, presentationTime: CMTime) {
        var timingInfo = CMSampleTimingInfo(
            duration: .invalid,
            presentationTimeStamp: presentationTime,
            decodeTimeStamp: .invalid
        )
        var videoFormatDescription: CMVideoFormatDescription?
        var status = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &videoFormatDescription
        )
        guard status == noErr else {
            return
        }
        var sampleBuffer: CMSampleBuffer?
        status = CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: videoFormatDescription!,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sampleBuffer
        )
        guard let sampleBuffer, status == noErr else {
            return
        }
        appendSampleBuffer(sampleBuffer, withType: .video)
    }
}

#if os(macOS)
extension NetStream: SCStreamOutput {
    @available(macOS 12.3, *)
    public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        if #available(macOS 13.0, *) {
            switch type {
            case .screen:
                appendSampleBuffer(sampleBuffer, withType: .video)
            default:
                appendSampleBuffer(sampleBuffer, withType: .audio)
            }
        } else {
            appendSampleBuffer(sampleBuffer, withType: .video)
        }
    }
}
#endif
