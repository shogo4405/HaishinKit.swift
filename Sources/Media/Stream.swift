import Foundation
import AVFoundation

// MARK: StreamDrawable
protocol StreamDrawable: class {
    var orientation:AVCaptureVideoOrientation { get set }
    var position:AVCaptureDevicePosition { get set }
    func drawImage(image:CIImage)
    func render(image:CIImage, toCVPixelBuffer:CVPixelBuffer)
}

// MARK: -
public class Stream: NSObject {
    var mixer:AVMixer = AVMixer()
    let lockQueue:dispatch_queue_t = dispatch_queue_create(
        "com.github.shogo4405.lf.Stream.lock", DISPATCH_QUEUE_SERIAL
    )

    #if os(iOS)
    public var torch:Bool {
        get {
            var torch:Bool = false
            dispatch_sync(lockQueue) {
                torch = self.mixer.videoIO.torch
            }
            return torch
        }
        set {
            dispatch_async(lockQueue) {
                self.mixer.videoIO.torch = newValue
            }
        }
    }
    public var syncOrientation:Bool {
        get {
            var syncOrientation:Bool = false
            dispatch_sync(lockQueue) {
                syncOrientation = self.mixer.syncOrientation
            }
            return syncOrientation
        }
        set {
            dispatch_async(lockQueue) {
                self.mixer.syncOrientation = newValue
            }
        }
    }
    #endif

    public var audioSettings:[String: AnyObject] {
        get {
            var audioSettings:[String: AnyObject]!
            dispatch_sync(lockQueue) {
                audioSettings = self.mixer.audioIO.encoder.dictionaryWithValuesForKeys(AACEncoder.supportedSettingsKeys)
            }
            return  audioSettings
        }
        set {
            dispatch_async(lockQueue) {
                self.mixer.audioIO.encoder.setValuesForKeysWithDictionary(newValue)
            }
        }
    }

    public var videoSettings:[String: AnyObject] {
        get {
            var videoSettings:[String:AnyObject]!
            dispatch_sync(lockQueue) {
                videoSettings = self.mixer.videoIO.encoder.dictionaryWithValuesForKeys(AVCEncoder.supportedSettingsKeys)
            }
            return videoSettings
        }
        set {
            dispatch_async(lockQueue) {
                self.mixer.videoIO.encoder.setValuesForKeysWithDictionary(newValue)
            }
        }
    }

    public var captureSettings:[String: AnyObject] {
        get {
            var captureSettings:[String: AnyObject]!
            dispatch_sync(lockQueue) {
                captureSettings = self.mixer.dictionaryWithValuesForKeys(AVMixer.supportedSettingsKeys)
            }
            return captureSettings
        }
        set {
            dispatch_async(lockQueue) {
                self.mixer.setValuesForKeysWithDictionary(newValue)
            }
        }
    }

    public var outputSettings:[String:[String:AnyObject]?] {
        get {
            var outputSettings:[String:[String:AnyObject]?]!
            dispatch_sync(lockQueue) {
                outputSettings = self.mixer.recorder.outputSettings
            }
            return outputSettings
        }
        set {
            dispatch_async(lockQueue) {
                self.mixer.recorder.outputSettings = newValue
            }
        }
    }

    public var recorderDelegate:AVMixerRecorderDelegate? {
        get {
            var recorderDelegate:AVMixerRecorderDelegate?
            dispatch_sync(lockQueue) {
                recorderDelegate = self.mixer.recorder.delegate
            }
            return recorderDelegate
        }
        set {
            dispatch_async(lockQueue) {
                self.mixer.recorder.delegate = newValue
            }
        }
    }

    public func attachCamera(camera:AVCaptureDevice?) {
        dispatch_async(lockQueue) {
            self.mixer.videoIO.attachCamera(camera)
            self.mixer.startRunning()
        }
    }

    public func attachAudio(audio:AVCaptureDevice?, _ automaticallyConfiguresApplicationAudioSession:Bool = true) {
        dispatch_async(lockQueue) {
            self.mixer.audioIO.attachAudio(audio, automaticallyConfiguresApplicationAudioSession: automaticallyConfiguresApplicationAudioSession
            )
        }
    }

    #if os(OSX)
    public func attachScreen(screen:AVCaptureScreenInput?) {
        dispatch_async(lockQueue) {
            self.mixer.videoIO.attachScreen(screen)
        }
    }
    #else
    public func attachScreen(screen:ScreenCaptureSession?, useScreenSize:Bool = true) {
        dispatch_async(lockQueue) {
            self.mixer.videoIO.attachScreen(screen, useScreenSize: useScreenSize)
        }
    }
    #endif

    public func registerEffect(video effect:VisualEffect) -> Bool {
        return mixer.videoIO.registerEffect(effect)
    }

    public func unregisterEffect(video effect:VisualEffect) -> Bool {
        return mixer.videoIO.unregisterEffect(effect)
    }

    public func setPointOfInterest(focus:CGPoint, exposure:CGPoint) {
        mixer.videoIO.focusPointOfInterest = focus
        mixer.videoIO.exposurePointOfInterest = exposure
    }
}
