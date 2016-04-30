#if os(iOS)
    import UIKit
#else
    import AppKit
#endif
import CoreImage
import Foundation
import AVFoundation

struct VideoIOData {
    var image:CGImageRef
    var presentationTimeStamp:CMTime
    var presentationDuration:CMTime
}

final class VideoIOComponent: NSObject {
    let lockQueue:dispatch_queue_t = dispatch_queue_create(
        "com.github.shogo4405.lf.VideoIOComponent.lock", DISPATCH_QUEUE_SERIAL
    )
    let bufferQueue:dispatch_queue_t = dispatch_queue_create(
        "com.github.shogo4405.lf.VideoIOComponent.buffer", DISPATCH_QUEUE_SERIAL
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
    private var buffers:[VideoIOData] = []
    private var effects:[VisualEffect] = []
    private var rendering:Bool = false

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
        defer {
            objc_sync_exit(effects)
        }
        if let _:Int = effects.indexOf(effect) {
            return false
        }
        effects.append(effect)
        return true
    }

    func unregisterEffect(effect:VisualEffect) -> Bool {
        objc_sync_enter(effects)
        defer {
            objc_sync_exit(effects)
        }
        if let i:Int = effects.indexOf(effect) {
            effects.removeAtIndex(i)
            return true
        }
        return false
    }

    func enqueSampleBuffer(bytes:[UInt8], inout timing:CMSampleTimingInfo) {
        dispatch_async(lockQueue) {
            var sample:[UInt8] = bytes
            let sampleSize:Int = bytes.count

            var blockBuffer:CMBlockBufferRef?
            guard CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault, &sample, sampleSize, kCFAllocatorNull, nil, 0, sampleSize, 0, &blockBuffer) == noErr else {
                return
            }

            var sampleBuffer:CMSampleBufferRef?
            var sampleSizes:[Int] = [sampleSize]
            guard IsNoErr(CMSampleBufferCreate(kCFAllocatorDefault, blockBuffer!, true, nil, nil, self.formatDescription!, 1, 1, &timing, 1, &sampleSizes, &sampleBuffer)) else {
                return
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

    func renderIfNeed() {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            guard !self.rendering else {
                return
            }
            self.rendering = true
            while (!self.buffers.isEmpty) {
                var buffer:VideoIOData?
                dispatch_sync(self.bufferQueue) {
                    buffer = self.buffers.removeFirst()
                }
                guard let data:VideoIOData = buffer else {
                    return
                }
                dispatch_async(dispatch_get_main_queue()) {
                    self.view.layer.contents = data.image
                }
                usleep(UInt32(data.presentationDuration.value) * 1000)
            }
            self.rendering = false
        }
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
            presentationDuration: CMSampleBufferGetDuration(sampleBuffer)
        )
        if (effects.isEmpty && view.layer.contents != nil) {
            dispatch_async(dispatch_get_main_queue()) {
                self.view.layer.contents = nil
            }
        }
    }
}

// MARK: - VideoDecoderDelegate
extension VideoIOComponent: VideoDecoderDelegate {
    func imageOutput(imageBuffer:CVImageBuffer!, presentationTimeStamp:CMTime, presentationDuration:CMTime) {
        let image:CIImage = CIImage(CVPixelBuffer: imageBuffer)
        let content:CGImageRef = context.createCGImage(image, fromRect: image.extent)
        dispatch_async(bufferQueue) {
            self.buffers.append(VideoIOData(
                image: content,
                presentationTimeStamp: presentationTimeStamp,
                presentationDuration: presentationDuration
            ))
        }
        renderIfNeed()
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
            presentationDuration: timestamp
        )
    }
}

// MARK: - VideoIOLayer
final class VideoIOLayer: AVCaptureVideoPreviewLayer {
    private(set) var currentFPS:Int = 0
    
    private var timer:NSTimer?
    private var frameCount:Int = 0
    private var surface:CALayer = CALayer()
    
    override init() {
        super.init()
        initialize()
    }
    
    override init!(session: AVCaptureSession!) {
        super.init(session: session)
        initialize()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialize()
    }
    
    deinit {
        timer?.invalidate()
        timer = nil
    }
    
    override var transform:CATransform3D {
        get {
            return surface.transform
        }
        set {
            surface.transform = newValue
        }
    }
    
    override var frame:CGRect {
        get {
            return super.frame
        }
        set {
            super.frame = newValue
            surface.frame = newValue
        }
    }
    
    override var contents:AnyObject? {
        get {
            return surface.contents
        }
        set {
            surface.contents = newValue
            frameCount += 1
        }
    }
    
    override var videoGravity:String! {
        get {
            return super.videoGravity
        }
        set {
            super.videoGravity = newValue
            switch newValue {
            case AVLayerVideoGravityResizeAspect:
                surface.contentsGravity = kCAGravityResizeAspect
            case AVLayerVideoGravityResizeAspectFill:
                surface.contentsGravity = kCAGravityResizeAspectFill
            case AVLayerVideoGravityResize:
                surface.contentsGravity = kCAGravityResize
            default:
                surface.contentsGravity = kCAGravityResizeAspect
            }
        }
    }
    
    private func initialize() {
        timer = NSTimer.scheduledTimerWithTimeInterval(
            1.0, target: self, selector: #selector(VideoIOLayer.didTimerInterval(_:)), userInfo: nil, repeats: true
        )
        addSublayer(surface)
    }
    
    func didTimerInterval(timer:NSTimer) {
        currentFPS = frameCount
        frameCount = 0
    }
}

#if os(iOS)
// MARK: - VideoIOView
public class VideoIOView: UIView {
    static var defaultBackgroundColor:UIColor = UIColor.blackColor()

    required override public init(frame: CGRect) {
        super.init(frame: frame)
        initialize()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialize()
    }

    public var videoGravity:String! = AVLayerVideoGravityResizeAspectFill {
        didSet {
            layer.setValue(videoGravity, forKey: "videoGravity")
        }
    }

    override public class func layerClass() -> AnyClass {
        return VideoIOLayer.self
    }

    private func initialize() {
        backgroundColor = VideoIOView.defaultBackgroundColor
        layer.frame = bounds
        layer.setValue(videoGravity, forKey: "videoGravity")
    }
}
#else
public class VideoIOView {
    public var layer:CALayer!
}
#endif
