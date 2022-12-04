import CoreMedia
import Foundation

/// The interface a capture session uses to inform its delegate.
public protocol CaptureSessionDelegate: AnyObject {
    /// Tells the receiver to set a size.
    func session(_ session: CaptureSessionConvertible, didSet size: CGSize)
    /// Tells the receiver to output a pixel buffer.
    func session(_ session: CaptureSessionConvertible, didOutput pixelBuffer: CVPixelBuffer, presentationTime: CMTime)
}

public protocol CaptureSessionConvertible: Running {
    var attributes: [NSString: NSObject] { get }
    var delegate: CaptureSessionDelegate? { get set }
}
