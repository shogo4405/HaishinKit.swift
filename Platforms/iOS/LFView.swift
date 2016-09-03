import Foundation
import AVFoundation

open class LFView: UIView {
    open static var defaultBackgroundColor:UIColor = UIColor.black

    open override class var layerClass:AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }

    open var videoGravity:String = AVLayerVideoGravityResizeAspect {
        didSet {
            layer.setValue(videoGravity, forKey: "videoGravity")
        }
    }

    var orientation:AVCaptureVideoOrientation = .portrait {
        didSet {
            guard let connection:AVCaptureConnection = layer.value(forKey: "connection") as? AVCaptureConnection else {
                return
            }
            if (connection.isVideoOrientationSupported) {
                connection.videoOrientation = orientation
            }
        }
    }
    var position:AVCaptureDevicePosition = .front

    public override init(frame:CGRect) {
        super.init(frame:frame)
        awakeFromNib()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override open func awakeFromNib() {
        backgroundColor = LFView.defaultBackgroundColor
        layer.contentsGravity = kCAGravityResizeAspect
        layer.backgroundColor = LFView.defaultBackgroundColor.cgColor
    }

    fileprivate weak var currentStream:Stream? {
        didSet {
            guard let oldValue:Stream = oldValue else {
                return
            }
            oldValue.mixer.videoIO.drawable = nil
        }
    }

    open func attachStream(_ stream:Stream?) {
        layer.setValue(stream?.mixer.session, forKey: "session")
        stream?.mixer.videoIO.drawable = self
        currentStream = stream
    }
}

// MARK: - StreamDrawable
extension LFView: StreamDrawable {
    func render(_ image: CIImage, toCVPixelBuffer: CVPixelBuffer) {
    }
    func drawImage(_ image:CIImage) {
    }
}
