import CoreImage
import Foundation
import AVFoundation

final class VideoIOComponent: NSObject {
    let lockQueue:dispatch_queue_t = dispatch_queue_create(
        "com.github.shogo4405.lf.VideoIOComponent.lock", DISPATCH_QUEUE_SERIAL
    )

    var view:VideoIOView = VideoIOView()
    var encoder:AVCEncoder = AVCEncoder()
    var decoder:AVCDecoder = AVCDecoder()

    var formatDescription:CMVideoFormatDescriptionRef? {
        didSet {
            decoder.formatDescription = formatDescription
        }
    }

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
        super.init()
        encoder.lockQueue = lockQueue
        decoder.lockQueue = lockQueue
        decoder.delegate = self
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
                self.view.layer.contents = content
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
        view.layer.setValue(!effects.isEmpty, forKey: "enabledSurface")
        objc_sync_exit(effects)
        return true
    }

    func unregisterEffect(effect:VisualEffect) -> Bool {
        objc_sync_enter(effects)
        if let i:Int = effects.indexOf(effect) {
            effects.removeAtIndex(i)
            view.layer.setValue(!effects.isEmpty, forKey: "enabledSurface")
            objc_sync_exit(effects)
            return true
        }
        objc_sync_exit(effects)
        return false
    }

    func enqueSampleBuffer(bytes:[UInt8], timestamp:Double) {
        dispatch_async(lockQueue) {
            var sample:[UInt8] = bytes
            let sampleSize:Int = bytes.count

            var blockBuffer:CMBlockBufferRef?
            guard CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault, &sample, sampleSize, kCFAllocatorNull, nil, 0, sampleSize, 0, &blockBuffer) == noErr else {
                return
            }

            var sampleBuffer:CMSampleBufferRef?
            var sampleSizes:[Int] = [sampleSize]
            var timing:CMSampleTimingInfo = CMSampleTimingInfo()
            timing.duration = CMTimeMake(Int64(timestamp), 1000)
            guard CMSampleBufferCreate(kCFAllocatorDefault, blockBuffer!, true, nil, nil, self.formatDescription!, 1, 1, &timing, 1, &sampleSizes, &sampleBuffer) == noErr else {
                return
            }

            let naluType:NALUType? = NALUType(bytes: bytes, naluLength: 4)
            let attachments:CFArrayRef = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer!, true)!
            for i:CFIndex in 0..<CFArrayGetCount(attachments) {
                naluType?.setCMSampleAttachmentValues(unsafeBitCast(CFArrayGetValueAtIndex(attachments, i), CFMutableDictionaryRef.self))
            }

            self.decoder.decodeSampleBuffer(sampleBuffer!)
        }
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

// MARK: - VideoDecoderDelegate
extension VideoIOComponent: VideoDecoderDelegate {
    func imageOutput(imageBuffer:CVImageBuffer!, presentationTimeStamp:CMTime, presentationDuration:CMTime) {
        view.layer.setValue(true, forKey: "enabledSurface")
        autoreleasepool {
            let image:CIImage = CIImage(CVPixelBuffer: imageBuffer)
            let content:CGImageRef = context.createCGImage(image, fromRect: image.extent)
            dispatch_async(dispatch_get_main_queue()) {
                self.view.layer.contents = content
            }
        }
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
