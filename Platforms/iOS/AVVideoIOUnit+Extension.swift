#if os(iOS)

import AVFoundation
import CoreImage

extension AVVideoIOUnit {
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
        } catch let error as NSError {
            logger.error("while locking device for ramp: \(error)")
        }
    }

    func attachScreen(_ screen: CaptureSessionConvertible?, useScreenSize: Bool = true) {
        guard let screen = screen else {
            self.screen?.stopRunning()
            self.screen = nil
            return
        }
        capture = nil
        if useScreenSize {
            codec.width = screen.attributes["Width"] as! Int32
            codec.height = screen.attributes["Height"] as! Int32
        }
        self.screen = screen
    }
}

extension AVVideoIOUnit: CaptureSessionDelegate {
    // MARK: CaptureSessionDelegate
    func session(_ session: CaptureSessionConvertible, didSet size: CGSize) {
        lockQueue.async {
            self.codec.width = Int32(size.width)
            self.codec.height = Int32(size.height)
        }
    }

    func session(_ session: CaptureSessionConvertible, didOutput pixelBuffer: CVPixelBuffer, presentationTime: CMTime) {
        if !effects.isEmpty {
            // usually the context comes from HKView or MTLHKView
            // but if you have not attached a view then the context is nil
            if context == nil {
                logger.info("no ci context, creating one to render effect")
                context = CIContext()
            }
            context?.render(effect(pixelBuffer, info: nil), to: pixelBuffer)
        }
        codec.inputBuffer(
            pixelBuffer,
            presentationTimeStamp: presentationTime,
            duration: CMTime.invalid
        )
        mixer?.recorder.appendPixelBuffer(pixelBuffer, withPresentationTime: presentationTime)
    }
}

#endif
