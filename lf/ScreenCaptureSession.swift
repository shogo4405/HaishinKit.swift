import Foundation

public final class ScreenCaptureSession:NSObject {
    private var running:Bool = false
    private var displayLink:CADisplayLink!
    private let lockQueue:dispatch_queue_t = dispatch_queue_create("com.github.shogo4405.lf.ScreenCaptureSession.lock", DISPATCH_QUEUE_SERIAL)
    
    public func startRunning() {
        dispatch_sync(lockQueue) {
            self.running = true
            self.displayLink = CADisplayLink(target: self, selector: "onScreen")
            self.displayLink.addToRunLoop(NSRunLoop.mainRunLoop(), forMode: NSRunLoopCommonModes)
        }
    }
    
    public func stopRunning() {
        dispatch_sync(lockQueue) {
            self.displayLink.removeFromRunLoop(NSRunLoop.mainRunLoop(), forMode: NSRunLoopCommonModes)
            self.displayLink = nil
            self.running = false
        }
    }
    
    public func onScreen() {
    }
}
