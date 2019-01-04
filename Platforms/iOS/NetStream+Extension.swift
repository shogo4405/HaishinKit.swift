import AVFoundation
import Foundation

extension NetStream {
    open var orientation: AVCaptureVideoOrientation {
        get {
            return mixer.videoIO.orientation
        }
        set {
            self.mixer.videoIO.orientation = newValue
        }
    }

    open func attachScreen(_ screen: ScreenCaptureSession?, useScreenSize: Bool = true) {
        lockQueue.async {
            self.mixer.videoIO.attachScreen(screen, useScreenSize: useScreenSize)
        }
    }

    open var zoomFactor: CGFloat {
        return self.mixer.videoIO.zoomFactor
    }

    open func setZoomFactor(_ zoomFactor: CGFloat, ramping: Bool = false, withRate: Float = 2.0) {
        self.mixer.videoIO.setZoomFactor(zoomFactor, ramping: ramping, withRate: withRate)
    }
}
