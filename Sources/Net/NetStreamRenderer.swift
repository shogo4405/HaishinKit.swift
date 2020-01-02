import AVFoundation
import Foundation

protocol NetStreamRenderer: class {
#if os(iOS) || os(macOS)
    var orientation: AVCaptureVideoOrientation { get set }
    var position: AVCaptureDevice.Position { get set }
#endif
    var videoFormatDescription: CMVideoFormatDescription? { get }

    func draw(image: CIImage)
    func attachStream(_ stream: NetStream?)
}
