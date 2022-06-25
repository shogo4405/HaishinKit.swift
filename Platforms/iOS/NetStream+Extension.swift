#if os(iOS)

import AVFoundation
import Foundation

extension NetStream {
    public var orientation: AVCaptureVideoOrientation {
        get {
            mixer.videoIO.orientation
        }
        set {
            self.mixer.videoIO.orientation = newValue
        }
    }

    public func attachScreen(_ screen: CaptureSessionConvertible?, useScreenSize: Bool = true) {
        lockQueue.async {
            self.mixer.videoIO.attachScreen(screen, useScreenSize: useScreenSize)
        }
    }

    public var zoomFactor: CGFloat {
        self.mixer.videoIO.zoomFactor
    }

    public func setZoomFactor(_ zoomFactor: CGFloat, ramping: Bool = false, withRate: Float = 2.0) {
        self.mixer.videoIO.setZoomFactor(zoomFactor, ramping: ramping, withRate: withRate)
    }
}

#endif
