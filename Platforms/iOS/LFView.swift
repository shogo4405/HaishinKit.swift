import Foundation
import AVFoundation

public class LFView: UIView {
    public override class func layerClass() -> AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }

    public var videoGravity:String = AVLayerVideoGravityResizeAspect {
        didSet {
            layer.setValue(videoGravity, forKey: "videoGravity")
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
