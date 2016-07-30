import Foundation
import AVFoundation

public class LFView: UIView {
    public static var defaultBackgroundColor:UIColor = UIColor.blackColor()

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

    public override init(frame:CGRect) {
        super.init(frame:frame)
        awakeFromNib()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override public func awakeFromNib() {
        backgroundColor = LFView.defaultBackgroundColor
        layer.contentsGravity = kCAGravityResizeAspect
        layer.backgroundColor = LFView.defaultBackgroundColor.CGColor
    }

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
