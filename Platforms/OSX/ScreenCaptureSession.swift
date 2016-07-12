import Foundation

public final class ScreenCaptureSession: NSObject {
    private(set) var running:Bool = false
    public var attributes:[NSString:NSObject] = [:]
    public weak var delegate:ScreenCaptureOutputPixelBufferDelegate?
}

// MARK: Runnable
extension ScreenCaptureSession: Runnable {
    public func startRunning() {}
    public func stopRunning() {}
}
