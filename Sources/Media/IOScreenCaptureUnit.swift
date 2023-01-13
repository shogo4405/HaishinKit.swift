import CoreMedia
import Foundation

/// The interface a capture session uses to inform its delegate.
public protocol IOScreenCaptureUnitDelegate: AnyObject {
    /// Tells the receiver to output a pixel buffer.
    func session(_ session: IOScreenCaptureUnit, didOutput pixelBuffer: CVPixelBuffer, presentationTime: CMTime)
}

/// The interface that provides methods to screen capture.
public protocol IOScreenCaptureUnit: Running {
    /// Specifies the CVPixelBufferPool's attributes.
    var attributes: [NSString: NSObject] { get }
    /// Specifies the delegate.
    var delegate: IOScreenCaptureUnitDelegate? { get set }
}
