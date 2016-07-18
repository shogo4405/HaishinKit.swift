import Foundation
import AVFoundation

public class LFView: UIView {
    public override class func layerClass() -> AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }

    public var videoGravity:String! = AVLayerVideoGravityResize {
        didSet {
            switch videoGravity {
            case AVLayerVideoGravityResizeAspect:
                layer.contentsGravity = kCAGravityResizeAspect
            case AVLayerVideoGravityResizeAspectFill:
                layer.contentsGravity = kCAGravityResizeAspectFill
            case AVLayerVideoGravityResize:
                layer.contentsGravity = kCAGravityResize
            default:
                layer.contentsGravity = kCAGravityResizeAspect
            }
        }
    }

    var orientation:AVCaptureVideoOrientation = .Portrait {
        didSet {
            guard let connection:AVCaptureConnection = layer.valueForKey("connection") as? AVCaptureConnection else {
                return
            }
            if (connection.supportsVideoOrientation) {
                connection.videoOrientation = orientation
            }
        }
    }
    var position:AVCaptureDevicePosition = .Front

    private weak var currentStream:Stream? {
        didSet {
            guard let oldValue:Stream = oldValue else {
                return
            }
            oldValue.mixer.videoIO.drawable = nil
        }
    }

    public func attachStream(stream:Stream?) {
        layer.setValue(stream?.mixer.session, forKey: "session")
        stream?.mixer.videoIO.drawable = self
        currentStream = stream
    }
}

// MARK: - StreamDrawable
extension LFView: StreamDrawable {
    func render(image: CIImage, toCVPixelBuffer: CVPixelBuffer) {
    }
    func drawImage(image:CIImage) {
    }
}
