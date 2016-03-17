import CoreImage
import Foundation
import AVFoundation

final class VideoIOComponent: NSObject {
    var layer:VideoPreviewLayer = VideoPreviewLayer()
    var encoder:AVCEncoder = AVCEncoder()
    let lockQueue:dispatch_queue_t = dispatch_queue_create(
        "com.github.shogo4405.lf.VideoIOComponent.lock", DISPATCH_QUEUE_SERIAL
    )
    private var context:CIContext = {
        if let context:CIContext = CIContext(options: [kCIContextUseSoftwareRenderer: NSNumber(bool: false)]) {
            logger.debug("cicontext use hardware renderer")
            return context
        }
        logger.debug("cicontext use software renderer")
        return CIContext()
    }()
    private var effects:[VisualEffect] = []

    override init() {
        encoder.lockQueue = lockQueue
    }

    func effect(buffer:CVImageBufferRef) -> CVImageBufferRef {
        CVPixelBufferLockBaseAddress(buffer, 0)
        let width:Int = CVPixelBufferGetWidth(buffer)
        let height:Int = CVPixelBufferGetHeight(buffer)
        var image:CIImage = CIImage(CVPixelBuffer: buffer)
        autoreleasepool {
            for effect in effects {
                image = effect.execute(image)
            }
            let content:CGImageRef = context.createCGImage(image, fromRect: image.extent)
            dispatch_async(dispatch_get_main_queue()) {
                self.layer.image.contents = content
            }
        }
        CVPixelBufferUnlockBaseAddress(buffer, 0)
        return createImageBuffer(image, width, height)!
    }

    func registerEffect(effect:VisualEffect) -> Bool {
        objc_sync_enter(effects)
        if let _:Int = effects.indexOf(effect) {
            objc_sync_exit(effects)
            return false
        }
        effects.append(effect)
        layer.useCIContext = !effects.isEmpty
        objc_sync_exit(effects)
        return true
    }

    func unregisterEffect(effect:VisualEffect) -> Bool {
        objc_sync_enter(effects)
        if let i:Int = effects.indexOf(effect) {
            effects.removeAtIndex(i)
            layer.useCIContext = !effects.isEmpty
            objc_sync_exit(effects)
            return true
        }
        objc_sync_exit(effects)
        return false
    }

    func createImageBuffer(image:CIImage, _ width:Int, _ height:Int) -> CVImageBufferRef? {
        var buffer:CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, nil, &buffer)
        CVPixelBufferLockBaseAddress(buffer!, 0)
        context.render(image, toCVPixelBuffer: buffer!)
        CVPixelBufferUnlockBaseAddress(buffer!, 0)
        return buffer
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension VideoIOComponent: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        guard let image:CVImageBufferRef = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        encoder.encodeImageBuffer(
            effects.isEmpty ? image : effect(image),
            presentationTimeStamp: CMSampleBufferGetPresentationTimeStamp(sampleBuffer),
            duration: CMSampleBufferGetDuration(sampleBuffer)
        )
    }
}

// MARK: - ScreenCaptureOutputPixelBufferDelegate
extension VideoIOComponent: ScreenCaptureOutputPixelBufferDelegate {
    func didSetSize(size: CGSize) {
        dispatch_async(lockQueue) {
            self.encoder.width = Int32(size.width)
            self.encoder.height = Int32(size.height)
        }
    }
    func pixelBufferOutput(pixelBuffer:CVPixelBufferRef, timestamp:CMTime) {
        encoder.encodeImageBuffer(
            pixelBuffer,
            presentationTimeStamp: timestamp,
            duration: timestamp
        )
    }
}
