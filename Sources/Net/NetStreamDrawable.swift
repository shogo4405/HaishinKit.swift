import AVFoundation
import Foundation

/// An interface that manages the NetStream content on the screen.
public protocol NetStreamDrawable: AnyObject {
    #if os(iOS) || os(macOS)
    /// Specifies the orientation of AVCaptureVideoOrientation.
    var videoOrientation: AVCaptureVideoOrientation { get set }
    #endif

    /// Attaches a drawable to a new NetStream object.
    func attachStream(_ stream: NetStream?)

    /// Enqueue a CMSampleBuffer? to draw.
    func enqueue(_ sampleBuffer: CMSampleBuffer?)
}
