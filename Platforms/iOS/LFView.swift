import Foundation
import AVFoundation

open class LFView: UIView {
    open static var defaultBackgroundColor:UIColor = UIColor.black

    open override class var layerClass:AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }

    public var videoGravity:String = AVLayerVideoGravityResizeAspect {
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

    private weak var currentStream:NetStream? {
        didSet {
            guard let oldValue:NetStream = oldValue else {
                return
            }
            oldValue.mixer.videoIO.drawable = nil
        }
    }

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

    open func attachStream(_ stream:NetStream?) {
        layer.setValue(stream?.mixer.session, forKey: "session")
        stream?.mixer.videoIO.drawable = self
        currentStream = stream
    }
}

extension LFView: NetStreamDrawable {
    func render(image: CIImage, to toCVPixelBuffer: CVPixelBuffer) {
    }
    func draw(image:CIImage) {
    }
}
