import UIKit
import Foundation
import AVFoundation

public protocol ScreenCaptureOutputPixelBufferDelegate:class {
    func pixelBufferOutput(pixelBuffer:CVPixelBufferRef, timestamp:CMTime)
}

public final class ScreenCaptureSession:NSObject {
    static let defaultAttributes:[NSString:NSObject] = [
        kCVPixelBufferPixelFormatTypeKey: NSNumber(unsignedInt:kCVPixelFormatType_32BGRA),
        kCVPixelBufferCGBitmapContextCompatibilityKey: true
    ]

    public var attributes:[NSString:NSObject] = ScreenCaptureSession.defaultAttributes
    public weak var delegate:ScreenCaptureOutputPixelBufferDelegate?

    private var running:Bool = false
    private var displayLink:CADisplayLink!
    private var colorSpace:CGColorSpaceRef!
    private var pixelBufferPool:CVPixelBufferPool?
    private let semaphore:dispatch_semaphore_t = dispatch_semaphore_create(1)
    private let lockQueue:dispatch_queue_t = {
        var queue:dispatch_queue_t = dispatch_queue_create("com.github.shogo4405.lf.ScreenCaptureSession.lock", DISPATCH_QUEUE_SERIAL)
        dispatch_set_target_queue(queue, dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_HIGH, 0))
        return queue
    }()

    private lazy var size:CGSize = {
        return UIApplication.sharedApplication().delegate!.window!!.bounds.size
    }()

    private lazy var scale:CGFloat = {
        return UIScreen.mainScreen().scale
    }()

    public func onScreen(displayLink:CADisplayLink) {
        if (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW) != 0) {
            return;
        }
        dispatch_async(lockQueue) {
            autoreleasepool {
                self.onScreenProcess(displayLink)
            }
            dispatch_semaphore_signal(self.semaphore)
        }
    }

    private func onScreenProcess(displayLink:CADisplayLink) {
        var pixelBuffer:CVPixelBufferRef?
        CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool!, &pixelBuffer)
        CVPixelBufferLockBaseAddress(pixelBuffer!, 0)

        let context:CGContextRef = createContext(pixelBuffer!)
        dispatch_sync(dispatch_get_main_queue()) {
            UIGraphicsPushContext(context)
            for window:UIWindow in UIApplication.sharedApplication().windows {
                window.drawViewHierarchyInRect(CGRect(x: 0, y: 0, width: self.size.width * self.scale, height: self.size.height * self.scale), afterScreenUpdates: true)
            }
            UIGraphicsPopContext()
        }
        delegate?.pixelBufferOutput(pixelBuffer!, timestamp: CMTimeMakeWithSeconds(displayLink.timestamp, 1000))
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, 0)
    }

    private func createContext(pixelBuffer:CVPixelBufferRef) -> CGContextRef {
        
        let bitmapInfo:CGBitmapInfo = CGBitmapInfo(rawValue:
            CGImageAlphaInfo.PremultipliedFirst.rawValue | CGBitmapInfo.ByteOrder32Little.rawValue
        )

        let context:CGContextRef = CGBitmapContextCreate(
            CVPixelBufferGetBaseAddress(pixelBuffer),
            CVPixelBufferGetWidth(pixelBuffer),
            CVPixelBufferGetHeight(pixelBuffer),
            8,
            CVPixelBufferGetBytesPerRow(pixelBuffer),
            colorSpace,
            bitmapInfo.rawValue
        )!

        CGContextScaleCTM(context, scale, scale);
        CGContextConcatCTM(context, CGAffineTransformMake(1, 0, 0, -1, 0, size.height))

        return context
    }
}

// MARK - Runnable
extension ScreenCaptureSession: Runnable {
    public func startRunning() {
        dispatch_sync(lockQueue) {
            guard self.running else {
                return
            }
            self.running = true
            self.pixelBufferPool = nil
            self.attributes[kCVPixelBufferWidthKey] = self.size.width * self.scale
            self.attributes[kCVPixelBufferHeightKey] = self.size.height * self.scale
            self.attributes[kCVPixelBufferBytesPerRowAlignmentKey] = self.size.width * 4
            self.colorSpace = CGColorSpaceCreateDeviceRGB()
            self.displayLink = CADisplayLink(target: self, selector: "onScreen:")
            CVPixelBufferPoolCreate(nil, nil, self.attributes, &self.pixelBufferPool)
            self.displayLink.addToRunLoop(NSRunLoop.mainRunLoop(), forMode: NSRunLoopCommonModes)
        }
    }
    
    public func stopRunning() {
        dispatch_sync(lockQueue) {
            guard !self.running else {
                return
            }
            self.displayLink.removeFromRunLoop(NSRunLoop.mainRunLoop(), forMode: NSRunLoopCommonModes)
            self.colorSpace = nil
            self.displayLink = nil
            self.running = false
        }
    }
}
