import AVFoundation
import Foundation

#if os(macOS)
typealias NetStreamRendererView = NSView
#else
typealias NetStreamRendererView = UIView
#endif

protocol NetStreamRenderer: class {
#if os(iOS) || os(macOS)
    var orientation: AVCaptureVideoOrientation { get set }
    var position: AVCaptureDevice.Position { get set }
#endif
    var displayImage: CIImage? { get set }
    var videoFormatDescription: CMVideoFormatDescription? { get }

    func render(image: CIImage?)
    func attachStream(_ stream: NetStream?)
}

extension NetStreamRenderer where Self: NetStreamRendererView {
    func render(image: CIImage?) {
        DispatchQueue.main.async {
            self.displayImage = image
            #if os(macOS)
            self.needsDisplay = true
            #else
            self.setNeedsDisplay()
            #endif
        }
    }
}
