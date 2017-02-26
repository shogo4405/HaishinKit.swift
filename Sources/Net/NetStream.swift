#if os(iOS)
import UIKit
#endif
import CoreImage
import Foundation
import AVFoundation

protocol NetStreamDrawable: class {
    var orientation:AVCaptureVideoOrientation { get set }
    var position:AVCaptureDevicePosition { get set }

    func draw(image:CIImage)
    func attachStream(_ stream:NetStream?)
    func render(image: CIImage, to toCVPixelBuffer: CVPixelBuffer)
}

// MARK: -
open class NetStream: NSObject {
    public private(set) var mixer:AVMixer = AVMixer()
    public let lockQueue:DispatchQueue = DispatchQueue(label: "com.github.shogo4405.lf.NetStream.lock")

    deinit {
        metadata.removeAll()
        NotificationCenter.default.removeObserver(self)
    }

    open var metadata:[String:NSObject] = [:]

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

    #if os(iOS)
    open var orientation:AVCaptureVideoOrientation {
        get {
            return mixer.videoIO.orientation
        }
        set {
            self.mixer.videoIO.orientation = newValue
        }
    }
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
                videoSettings = self.mixer.videoIO.encoder.dictionaryWithValues(forKeys: AVCEncoder.supportedSettingsKeys)
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

    open var recorderSettings:[String:[String:Any]] {
        get {
            var recorderSettings:[String:[String:Any]]!
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

    open func attachCamera(_ camera:AVCaptureDevice?) {
        lockQueue.async {
            self.mixer.videoIO.attachCamera(camera)
        }
    }

    open func attachAudio(_ audio:AVCaptureDevice?, automaticallyConfiguresApplicationAudioSession:Bool = true) {
        lockQueue.async {
            self.mixer.audioIO.attachAudio(audio,
                automaticallyConfiguresApplicationAudioSession: automaticallyConfiguresApplicationAudioSession
            )
        }
    }

    #if os(macOS)
    open func attachScreen(_ screen:AVCaptureScreenInput?) {
        lockQueue.async {
            self.mixer.videoIO.attachScreen(screen)
        }
    }
    #else
    open func attachScreen(_ screen:ScreenCaptureSession?, useScreenSize:Bool = true) {
        lockQueue.async {
            self.mixer.videoIO.attachScreen(screen, useScreenSize: useScreenSize)
        }
    }
    open func ramp(toVideoZoomFactor:CGFloat, withRate:Float) {
        lockQueue.async {
            self.mixer.videoIO.ramp(toVideoZoomFactor: toVideoZoomFactor, withRate: withRate)
        }
    }
    #endif

    open func appendSampleBuffer(_ sampleBuffer:CMSampleBuffer, withType: CMSampleBufferType, options:[NSObject: AnyObject]? = nil) {
        switch withType {
        case .audio:
            mixer.audioIO.captureOutput(nil, didOutputSampleBuffer: sampleBuffer, from: nil)
        case .video:
            mixer.videoIO.captureOutput(nil, didOutputSampleBuffer: sampleBuffer, from: nil)
        }
    }

    open func registerEffect(video effect:VisualEffect) -> Bool {
        return mixer.videoIO.registerEffect(effect)
    }

    open func unregisterEffect(video effect:VisualEffect) -> Bool {
        return mixer.videoIO.unregisterEffect(effect)
    }

    open func setPointOfInterest(_ focus:CGPoint, exposure:CGPoint) {
        mixer.videoIO.focusPointOfInterest = focus
        mixer.videoIO.exposurePointOfInterest = exposure
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
