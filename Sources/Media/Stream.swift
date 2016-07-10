import Foundation
import AVFoundation

public class Stream: NSObject {
    var mixer:AVMixer = AVMixer()
    let lockQueue:dispatch_queue_t = dispatch_queue_create(
        "com.github.shogo4405.lf.Stream.lock", DISPATCH_QUEUE_SERIAL
    )

    #if os(iOS)
    public var torch:Bool {
        get { return mixer.videoIO.torch }
        set { mixer.videoIO.torch = newValue }
    }
    public var syncOrientation:Bool {
        get { return mixer.syncOrientation }
        set { mixer.syncOrientation = newValue }
    }
    #endif

    public var view:VideoIOView {
        return mixer.videoIO.view
    }

    public var audioSettings:[String: AnyObject] {
        get { return mixer.audioIO.encoder.dictionaryWithValuesForKeys(AACEncoder.supportedSettingsKeys)}
        set { mixer.audioIO.encoder.setValuesForKeysWithDictionary(newValue) }
    }

    public var videoSettings:[String: AnyObject] {
        get { return mixer.videoIO.encoder.dictionaryWithValuesForKeys(AVCEncoder.supportedSettingsKeys)}
        set { mixer.videoIO.encoder.setValuesForKeysWithDictionary(newValue)}
    }

    public var captureSettings:[String: AnyObject] {
        get { return mixer.dictionaryWithValuesForKeys(AVMixer.supportedSettingsKeys)}
        set { mixer.setValuesForKeysWithDictionary(newValue) }
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

    public func attachScreen(screen:ScreenCaptureSession?, useScreenSize:Bool = true) {
        dispatch_async(lockQueue) {
            self.mixer.videoIO.attachScreen(screen, useScreenSize: useScreenSize)
        }
    }

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
