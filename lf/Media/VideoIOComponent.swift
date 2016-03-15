import CoreImage
import Foundation
import AVFoundation

final class VideoIOComponent: NSObject {

    static func getContentsGravity(videoGravity:String) -> String {
        switch videoGravity {
        case AVLayerVideoGravityResizeAspect:
            return kCAGravityResizeAspect
        case AVLayerVideoGravityResizeAspectFill:
            return kCAGravityResizeAspectFill
        case AVLayerVideoGravityResize:
            return kCAGravityResize
        default:
            return kCAGravityResizeAspect
        }
    }

    var layer:CALayer = CALayer()
    var encoder:AVCEncoder = AVCEncoder()
    let lockQueue:dispatch_queue_t = dispatch_queue_create(
        "com.github.shogo4405.lf.VideoIOComponent.lock", DISPATCH_QUEUE_SERIAL
    )
    private var context:CIContext = {
        if let context:CIContext = CIContext(options: [kCIContextUseSoftwareRenderer: NSNumber(bool: false)]) {
            logger.info("cicontext use hardware renderer")
            return context
        }
        logger.info("cicontext use software renderer")
        return CIContext()
    }()
    private var effects:[VisualEffect] = []

    override init() {
        encoder.lockQueue = lockQueue
    }

    func effect(buffer:CVImageBufferRef) -> CVImageBufferRef {
        CVPixelBufferLockBaseAddress(buffer, 0)
        var image:CIImage = CIImage(CVPixelBuffer: buffer)
        autoreleasepool {
            for effect in self.effects {
                image = effect.execute(image)
            }
            CVPixelBufferUnlockBaseAddress(buffer, 0)
            let content:CGImageRef = context.createCGImage(image, fromRect: image.extent)
            dispatch_async(dispatch_get_main_queue()) {
                self.layer.contents = content
            }
        }
        return createImageBuffer(image)!
    }

    func registerEffect(effect:VisualEffect) -> Bool {
        objc_sync_enter(effects)
        if let _:Int = effects.indexOf(effect) {
            objc_sync_exit(effects)
            return false
        }
        effects.append(effect)
        objc_sync_exit(effects)
        return true
    }

    func unregisterEffect(effect:VisualEffect) -> Bool {
        objc_sync_enter(effects)
        if let i:Int = effects.indexOf(effect) {
            effects.removeAtIndex(i)
            objc_sync_exit(effects)
            return true
        }
        objc_sync_exit(effects)
        return false
    }

    func createImageBuffer(image:CIImage) -> CVImageBufferRef? {
        var buffer:CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, Int(image.extent.width), Int(image.extent.height), kCVPixelFormatType_32BGRA, nil, &buffer)
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
            effect(image),
            presentationTimeStamp: CMSampleBufferGetPresentationTimeStamp(sampleBuffer),
            duration: CMSampleBufferGetDuration(sampleBuffer)
        )
    }
}

// MARK: - ScreenCaptureOutputPixelBufferDelegate
extension VideoIOComponent: ScreenCaptureOutputPixelBufferDelegate {
    func pixelBufferOutput(pixelBuffer:CVPixelBufferRef, timestamp:CMTime) {
        encoder.encodeImageBuffer(pixelBuffer,
            presentationTimeStamp: timestamp,
            duration: timestamp
        )
    }
}
