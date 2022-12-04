#if os(iOS)

import AVFoundation
import CoreImage

extension IOVideoUnit {
    var zoomFactor: CGFloat {
        guard let device = capture?.device else {
            return 0
        }
        return device.videoZoomFactor
    }

    func setZoomFactor(_ zoomFactor: CGFloat, ramping: Bool, withRate: Float) {
        guard let device = capture?.device,
              1 <= zoomFactor && zoomFactor < device.activeFormat.videoMaxZoomFactor
        else { return }
        do {
            try device.lockForConfiguration()
            if ramping {
                device.ramp(toVideoZoomFactor: zoomFactor, withRate: withRate)
            } else {
                device.videoZoomFactor = zoomFactor
            }
            device.unlockForConfiguration()
        } catch {
            logger.error("while locking device for ramp:", error)
        }
    }
}

#endif
