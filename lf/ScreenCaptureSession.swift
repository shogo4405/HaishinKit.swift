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

    private var timestamp:CFTimeInterval = 0
    private var running:Bool = false
    private var displayLink:CADisplayLink!
    private var colorSpace:CGColorSpaceRef!
    private var pixelBufferPool:CVPixelBufferPool?
    private let lockQueue:dispatch_queue_t = dispatch_queue_create("com.github.shogo4405.lf.ScreenCaptureSession.lock", DISPATCH_QUEUE_SERIAL)
    private lazy var size:CGSize = {
        return UIApplication.sharedApplication().delegate!.window!!.bounds.size
        }()

    public func startRunning() {
        dispatch_sync(lockQueue) {
            self.running = true
            self.pixelBufferPool = nil
            self.attributes[kCVPixelBufferWidthKey] = self.size.width
            self.attributes[kCVPixelBufferHeightKey] = self.size.height
            self.attributes[kCVPixelBufferBytesPerRowAlignmentKey] = self.size.width * 4
            self.colorSpace = CGColorSpaceCreateDeviceRGB()
            self.displayLink = CADisplayLink(target: self, selector: "onScreen:")
            CVPixelBufferPoolCreate(nil, nil, self.attributes, &self.pixelBufferPool)
            self.timestamp = self.displayLink.timestamp
            self.displayLink.addToRunLoop(NSRunLoop.mainRunLoop(), forMode: NSRunLoopCommonModes)
        }
    }
    
    public func stopRunning() {
        dispatch_sync(lockQueue) {
            self.displayLink.removeFromRunLoop(NSRunLoop.mainRunLoop(), forMode: NSRunLoopCommonModes)
            self.timestamp = 0
            self.colorSpace = nil
            self.displayLink = nil
            self.running = false
        }
    }
    
    public func onScreen() {
        var pixelBuffer:CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool!, &pixelBuffer)
        let context:CGContextRef = createContext(pixelBuffer!)
        UIGraphicsPushContext(context)
        for window:UIWindow in UIApplication.sharedApplication().windows {
            window.drawViewHierarchyInRect(CGRect(x: 0, y: 0, width: size.width,   height: size.height), afterScreenUpdates: true)
        }
        UIGraphicsPopContext()
        delegate?.pixelBufferOutput(pixelBuffer!, timestamp: CMTimeMakeWithSeconds(displayLink.timestamp - timestamp, 1000))
    }

    private func createContext(pixelBuffer:CVPixelBufferRef) -> CGContextRef {
        
        let bitmapInfo:CGBitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.None.rawValue)

        let context:CGContextRef = CGBitmapContextCreate(
            CVPixelBufferGetBaseAddress(pixelBuffer),
            CVPixelBufferGetWidth(pixelBuffer),
            CVPixelBufferGetHeight(pixelBuffer),
            8,
            CVPixelBufferGetBytesPerRow(pixelBuffer),
            colorSpace,
            bitmapInfo.rawValue
        )!

        return context
    }
}
