#if os(iOS)

import AVFoundation
import Foundation

extension NetStream {
    public var zoomFactor: CGFloat {
        self.mixer.videoIO.zoomFactor
    }

    public func setZoomFactor(_ zoomFactor: CGFloat, ramping: Bool = false, withRate: Float = 2.0) {
        self.mixer.videoIO.setZoomFactor(zoomFactor, ramping: ramping, withRate: withRate)
    }
}

#endif
