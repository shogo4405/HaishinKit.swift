import CoreMedia
import Foundation
import AVFoundation

extension VideoIOComponent {
    func ramp(toVideoZoomFactor:CGFloat, withRate:Float) {
        guard let device:AVCaptureDevice = (input as? AVCaptureDeviceInput)?.device,
            1 <= toVideoZoomFactor && toVideoZoomFactor < device.activeFormat.videoMaxZoomFactor else {
                return
        }
        do {
            try device.lockForConfiguration()
            device.ramp(toVideoZoomFactor: toVideoZoomFactor, withRate: withRate)
            device.unlockForConfiguration()
        } catch let error as NSError {
            logger.error("while locking device for ramp: \(error)")
        }
    }
    
    func attachScreen(_ screen:ScreenCaptureSession?, useScreenSize:Bool = true) {
        guard let screen:ScreenCaptureSession = screen else {
            self.screen?.stopRunning()
            self.screen = nil
            return
        }
        input = nil
        output = nil
        if (useScreenSize) {
            encoder.setValuesForKeys([
                "width": screen.attributes["Width"]!,
                "height": screen.attributes["Height"]!,
                ])
        }
        self.screen = screen
    }
}

extension VideoIOComponent: ScreenCaptureOutputPixelBufferDelegate {
    // MARK: ScreenCaptureOutputPixelBufferDelegate
    func didSet(size: CGSize) {
        lockQueue.async {
            self.encoder.width = Int32(size.width)
            self.encoder.height = Int32(size.height)
        }
    }
    func output(pixelBuffer:CVPixelBuffer, withPresentationTime:CMTime) {
        if (!effects.isEmpty) {
            drawable?.render(image: effect(pixelBuffer), to: pixelBuffer)
        }
        encoder.encodeImageBuffer(
            pixelBuffer,
            presentationTimeStamp: withPresentationTime,
            duration: kCMTimeInvalid
        )
        mixer?.recorder.appendPixelBuffer(pixelBuffer, withPresentationTime: withPresentationTime)
    }
}
