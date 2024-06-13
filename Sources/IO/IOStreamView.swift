import AVFoundation
import Foundation

/// An interface that manages the IOStream content on the screen.
@MainActor
public protocol IOStreamView: AnyObject {
    #if os(iOS) || os(tvOS) || os(macOS)
    /// Specifies the capture video preview enabled or not.
    /// Use AVCaptureVideoPreviewLayer as an internal implementation. You can verify that there is no delay in cinema mode. However, you cannot confirm the filter state.
    @available(tvOS 17.0, *)
    var isCaptureVideoPreviewEnabled: Bool { get set }
    #endif

    /// Attaches a drawable to a new NetStream object.
    func attachStream(_ stream: (some IOStreamConvertible)?)

    /// Enqueue a CMSampleBuffer? to draw.
    func enqueue(_ sampleBuffer: CMSampleBuffer?)
}
