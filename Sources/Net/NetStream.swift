import CoreImage
import Foundation
import AVFoundation

protocol NetStreamDrawable: class {
#if os(iOS) || os(macOS)
    var orientation:AVCaptureVideoOrientation { get set }
    var position:AVCaptureDevice.Position { get set }
#endif

    func draw(image:CIImage)
    func attachStream(_ stream:NetStream?)
}

// MARK: -
open class NetStream: NSObject {
    public private(set) var mixer:AVMixer = AVMixer()
    public let lockQueue:DispatchQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.NetStream.lock")

    deinit {
        metadata.removeAll()
        NotificationCenter.default.removeObserver(self)
    }

    open var metadata:[String: Any?] = [:]
    
    open var context:CIContext? {
        get {
            return mixer.videoIO.context
        }
        set {
            mixer.videoIO.context = context
        }
    }

#if os(iOS) || os(macOS)
    open var torch:Bool {
        get {
            var torch:Bool = false
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
#endif

    #if os(iOS)
    open var syncOrientation:Bool = false {
        didSet {
            guard syncOrientation != oldValue else {
                return
            }
            if (syncOrientation) {
                NotificationCenter.default.addObserver(self, selector: #selector(NetStream.on(uiDeviceOrientationDidChange:)), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
            } else {
                NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
            }
        }
    }
    #endif

    open var audioSettings:[String:Any] {
        get {
            var audioSettings:[String:Any]!
            lockQueue.sync {
                audioSettings = self.mixer.audioIO.encoder.dictionaryWithValues(forKeys: AACEncoder.supportedSettingsKeys)
            }
            return  audioSettings
        }
        set {
            lockQueue.sync {
                self.mixer.audioIO.encoder.setValuesForKeys(newValue)
            }
        }
    }

    open var videoSettings:[String:Any] {
        get {
            var videoSettings:[String:Any]!
            lockQueue.sync {
                videoSettings = self.mixer.videoIO.encoder.dictionaryWithValues(forKeys: H264Encoder.supportedSettingsKeys)
            }
            return videoSettings
        }
        set {
            lockQueue.sync {
                self.mixer.videoIO.encoder.setValuesForKeys(newValue)
            }
        }
    }

    open var captureSettings:[String:Any] {
        get {
            var captureSettings:[String:Any]!
            lockQueue.sync {
                captureSettings = self.mixer.dictionaryWithValues(forKeys: AVMixer.supportedSettingsKeys)
            }
            return captureSettings
        }
        set {
            lockQueue.sync {
                self.mixer.setValuesForKeys(newValue)
            }
        }
    }

    open var recorderSettings:[AVMediaType:[String:Any]] {
        get {
            var recorderSettings:[AVMediaType:[String:Any]]!
            lockQueue.sync {
                recorderSettings = self.mixer.recorder.outputSettings
            }
            return recorderSettings
        }
        set {
            lockQueue.sync {
                self.mixer.recorder.outputSettings = newValue
            }
        }
    }

#if os(iOS) || os(macOS)
    open func attachCamera(_ camera:AVCaptureDevice?, onError:((_ error:NSError) -> Void)? = nil) {
        lockQueue.async {
            do {
                try self.mixer.videoIO.attachCamera(camera)
            } catch let error as NSError {
                onError?(error)
            }
        }
    }

    open func attachAudio(_ audio:AVCaptureDevice?, automaticallyConfiguresApplicationAudioSession:Bool = false, onError:((_ error:NSError) -> Void)? = nil) {
        lockQueue.async {
            do {
                try self.mixer.audioIO.attachAudio(audio, automaticallyConfiguresApplicationAudioSession: automaticallyConfiguresApplicationAudioSession)
            } catch let error as NSError {
                onError?(error)
            }
        }
    }

    open func setPointOfInterest(_ focus:CGPoint, exposure:CGPoint) {
        mixer.videoIO.focusPointOfInterest = focus
        mixer.videoIO.exposurePointOfInterest = exposure
    }
#endif

    open func appendSampleBuffer(_ sampleBuffer:CMSampleBuffer, withType: CMSampleBufferType, options:[NSObject: AnyObject]? = nil) {
        switch withType {
        case .audio:
            mixer.audioIO.lockQueue.async {
                self.mixer.audioIO.appendSampleBuffer(sampleBuffer)
            }
        case .video:
            mixer.videoIO.lockQueue.async {
                self.mixer.videoIO.appendSampleBuffer(sampleBuffer)
            }
        }
    }

    open func registerEffect(video effect:VisualEffect) -> Bool {
        return mixer.videoIO.registerEffect(effect)
    }

    open func unregisterEffect(video effect:VisualEffect) -> Bool {
        return mixer.videoIO.unregisterEffect(effect)
    }

    open func dispose() {
        lockQueue.async {
            self.mixer.dispose()
        }
    }

    #if os(iOS)
    @objc private func on(uiDeviceOrientationDidChange:Notification) {
        if let orientation:AVCaptureVideoOrientation = DeviceUtil.videoOrientation(by: uiDeviceOrientationDidChange) {
            self.orientation = orientation
        }
    }
    #endif
}
