import AVFoundation
import Foundation

/// An interface that manages the NetStream content on the screen.
public protocol NetStreamDrawable: AnyObject {
    #if !os(tvOS)
    /// Specifies the orientation of AVCaptureVideoOrientation.
    var orientation: AVCaptureVideoOrientation { get set }

    /// Specifies the position of AVCaptureDevice.
    var position: AVCaptureDevice.Position { get set }
    #endif

    /// The videoFormatDescription which is the current CMSampleBuffer.
    var videoFormatDescription: CMVideoFormatDescription? { get }

    /// Attaches a drawable to a new NetStream object.
    func attachStream(_ stream: NetStream?)

    /// Enqueue a CMSampleBuffer? to draw.
    func enqueue(_ sampleBuffer: CMSampleBuffer?)
}
