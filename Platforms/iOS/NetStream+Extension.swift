import Foundation
import AVFoundation

extension NetStream {
    open var orientation:AVCaptureVideoOrientation {
        get {
            return mixer.videoIO.orientation
        }
        set {
            self.mixer.videoIO.orientation = newValue
        }
    }

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
}
