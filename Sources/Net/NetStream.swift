import Foundation
import AVFoundation

protocol NetStreamDrawable: class {
    var orientation:AVCaptureVideoOrientation { get set }
    var position:AVCaptureDevicePosition { get set }

    func draw(image:CIImage)
    func render(image: CIImage, to toCVPixelBuffer: CVPixelBuffer)
}

// MARK: -
open class NetStream: NSObject {
    var mixer:AVMixer = AVMixer()
    let lockQueue:DispatchQueue = DispatchQueue(
        label: "com.github.shogo4405.lf.Stream.lock", attributes: []
    )

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
    open var syncOrientation:Bool {
        get {
            var syncOrientation:Bool = false
            lockQueue.sync {
                syncOrientation = self.mixer.syncOrientation
            }
            return syncOrientation
        }
        set {
            lockQueue.async {
                self.mixer.syncOrientation = newValue
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
            lockQueue.async {
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
            lockQueue.async {
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
            lockQueue.async {
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
            lockQueue.async {
                self.mixer.recorder.outputSettings = newValue
            }
        }
    }

    open var recorderDelegate:AVMixerRecorderDelegate? {
        get {
            var recorderDelegate:AVMixerRecorderDelegate?
            lockQueue.sync {
                recorderDelegate = self.mixer.recorder.delegate
            }
            return recorderDelegate
        }
        set {
            lockQueue.async {
                self.mixer.recorder.delegate = newValue
            }
        }
    }

    open func attach(camera:AVCaptureDevice?) {
        lockQueue.async {
            self.mixer.videoIO.attach(camera: camera)
            self.mixer.startRunning()
        }
    }

    open func attach(audio:AVCaptureDevice?, automaticallyConfiguresApplicationAudioSession:Bool = true) {
        lockQueue.async {
            self.mixer.audioIO.attach(audio: audio, automaticallyConfiguresApplicationAudioSession: automaticallyConfiguresApplicationAudioSession
            )
        }
    }

    #if os(OSX)
    public func attach(screen:AVCaptureScreenInput?) {
        lockQueue.async {
            self.mixer.videoIO.attach(screen: screen)
        }
    }
    #else
    open func attach(screen:ScreenCaptureSession?, useScreenSize:Bool = true) {
        lockQueue.async {
            self.mixer.videoIO.attach(screen: screen, useScreenSize: useScreenSize)
        }
    }
    open func ramp(toVideoZoomFactor:CGFloat, withRate:Float) {
        lockQueue.async {
            self.mixer.videoIO.ramp(toVideoZoomFactor: toVideoZoomFactor, withRate: withRate)
        }
    }
    #endif

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
}
