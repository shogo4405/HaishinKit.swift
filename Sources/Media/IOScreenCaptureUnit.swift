import CoreMedia
import Foundation

/// The interface a capture session uses to inform its delegate.
public protocol IOScreenCaptureUnitDelegate: AnyObject {
    /// Tells the receiver to output a pixel buffer.
    func session(_ session: IOScreenCaptureUnit, didOutput pixelBuffer: CVPixelBuffer, presentationTime: CMTime)
}

public protocol IOScreenCaptureUnit: Running {
    var attributes: [NSString: NSObject] { get }
    var delegate: IOScreenCaptureUnitDelegate? { get set }
}
