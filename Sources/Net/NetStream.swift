import AVFoundation

protocol NetStreamDrawable: class {
#if os(iOS) || os(macOS)
    var orientation: AVCaptureVideoOrientation { get set }
    var position: AVCaptureDevice.Position { get set }
#endif

    func draw(image: CIImage)
    func attachStream(_ stream: NetStream?)
}

// MARK: -
open class NetStream: NSObject {
    public private(set) var mixer = AVMixer()
    private static let queueKey = DispatchSpecificKey<UnsafeMutableRawPointer>()
    private static let queueValue = UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1)
    public let lockQueue = ({ () -> DispatchQueue in
        let queue = DispatchQueue(label: "com.haishinkit.HaishinKit.NetStream.lock")
        queue.setSpecific(key: queueKey, value: queueValue)
        return queue
    })()

    deinit {
        metadata.removeAll()
        NotificationCenter.default.removeObserver(self)
    }

    open var metadata: [String: Any?] = [:]

    open var context: CIContext? {
        get {
            return mixer.videoIO.context
        }
        set {
            mixer.videoIO.context = newValue
        }
    }

#if os(iOS) || os(macOS)
    open var torch: Bool {
        get {
            var torch: Bool = false
            ensureLockQueue {
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
#endif

    #if os(iOS)
    open var syncOrientation: Bool = false {
        didSet {
            guard syncOrientation != oldValue else {
                return
            }
            if syncOrientation {
                NotificationCenter.default.addObserver(self, selector: #selector(on), name: UIDevice.orientationDidChangeNotification, object: nil)
            } else {
                NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
            }
        }
    }
    #endif

    open var audioSettings: [String: Any] {
        get {
            var audioSettings: [String: Any]!
            ensureLockQueue {
                audioSettings = self.mixer.audioIO.encoder.dictionaryWithValues(forKeys: AudioConverter.supportedSettingsKeys)
            }
            return  audioSettings
        }
        set {
            ensureLockQueue {
                self.mixer.audioIO.encoder.setValuesForKeys(newValue)
            }
        }
    }

    open var videoSettings: [String: Any] {
        get {
            var videoSettings: [String: Any]!
            ensureLockQueue {
                videoSettings = self.mixer.videoIO.encoder.dictionaryWithValues(forKeys: H264Encoder.supportedSettingsKeys)
            }
            return videoSettings
        }
        set {
            if DispatchQueue.getSpecific(key: NetStream.queueKey) == NetStream.queueValue {
                self.mixer.videoIO.encoder.setValuesForKeys(newValue)
            } else {
                ensureLockQueue {
                    self.mixer.videoIO.encoder.setValuesForKeys(newValue)
                }
            }
        }
    }

    open var captureSettings: [String: Any] {
        get {
            var captureSettings: [String: Any]!
            ensureLockQueue {
                captureSettings = self.mixer.dictionaryWithValues(forKeys: AVMixer.supportedSettingsKeys)
            }
            return captureSettings
        }
        set {
            ensureLockQueue {
                self.mixer.setValuesForKeys(newValue)
            }
        }
    }

    open var recorderSettings: [AVMediaType: [String: Any]] {
        get {
            var recorderSettings: [AVMediaType: [String: Any]]!
            ensureLockQueue {
                recorderSettings = self.mixer.recorder.outputSettings
            }
            return recorderSettings
        }
        set {
            ensureLockQueue {
                self.mixer.recorder.outputSettings = newValue
            }
        }
    }

#if os(iOS) || os(macOS)
    open func attachCamera(_ camera: AVCaptureDevice?, onError: ((_ error: NSError) -> Void)? = nil) {
        lockQueue.async {
            do {
                try self.mixer.videoIO.attachCamera(camera)
            } catch let error as NSError {
                onError?(error)
            }
        }
    }

    open func attachAudio(_ audio: AVCaptureDevice?, automaticallyConfiguresApplicationAudioSession: Bool = false, onError: ((_ error: NSError) -> Void)? = nil) {
        lockQueue.async {
            do {
                try self.mixer.audioIO.attachAudio(audio, automaticallyConfiguresApplicationAudioSession: automaticallyConfiguresApplicationAudioSession)
            } catch let error as NSError {
                onError?(error)
            }
        }
    }

    open func setPointOfInterest(_ focus: CGPoint, exposure: CGPoint) {
        mixer.videoIO.focusPointOfInterest = focus
        mixer.videoIO.exposurePointOfInterest = exposure
    }
#endif

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

    open func registerVideoEffect(_ effect: VideoEffect) -> Bool {
        return mixer.videoIO.lockQueue.sync {
            self.mixer.videoIO.registerEffect(effect)
        }
    }

    open func unregisterVideoEffect(_ effect: VideoEffect) -> Bool {
        return mixer.videoIO.lockQueue.sync {
            self.mixer.videoIO.unregisterEffect(effect)
        }
    }

    open func registerAudioEffect(_ effect: AudioEffect) -> Bool {
        return mixer.audioIO.lockQueue.sync {
            self.mixer.audioIO.registerEffect(effect)
        }
    }

    open func unregisterAudioEffect(_ effect: AudioEffect) -> Bool {
        return mixer.audioIO.lockQueue.sync {
            self.mixer.audioIO.unregisterEffect(effect)
        }
    }

    open func dispose() {
        lockQueue.async {
            self.mixer.dispose()
        }
    }

    #if os(iOS)
    @objc
    private func on(uiDeviceOrientationDidChange: Notification) {
        if let orientation: AVCaptureVideoOrientation = DeviceUtil.videoOrientation(by: uiDeviceOrientationDidChange) {
            self.orientation = orientation
        }
    }
    #endif

    func ensureLockQueue(callback: () -> Void) {
        if DispatchQueue.getSpecific(key: NetStream.queueKey) == NetStream.queueValue {
            callback()
        } else {
            lockQueue.sync {
                callback()
            }
        }
    }
}
