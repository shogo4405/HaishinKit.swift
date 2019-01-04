import AVFoundation
import UIKit

open class HKView: UIView {
    public static var defaultBackgroundColor: UIColor = .black

    override open class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }

    override open var layer: AVCaptureVideoPreviewLayer {
        return super.layer as! AVCaptureVideoPreviewLayer
    }

    public var videoGravity: AVLayerVideoGravity = .resizeAspect {
        didSet {
            layer.videoGravity = videoGravity
        }
    }

    var orientation: AVCaptureVideoOrientation = .portrait {
        didSet {
            layer.connection.map {
                if $0.isVideoOrientationSupported {
                    $0.videoOrientation = orientation
                }
            }
        }
    }
    var position: AVCaptureDevice.Position = .front

    private weak var currentStream: NetStream? {
        didSet {
            oldValue?.mixer.videoIO.drawable = nil
        }
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        awakeFromNib()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    deinit {
        attachStream(nil)
    }

    override open func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = HKView.defaultBackgroundColor
        layer.backgroundColor = HKView.defaultBackgroundColor.cgColor
    }

    open func attachStream(_ stream: NetStream?) {
        guard let stream: NetStream = stream else {
            layer.session?.stopRunning()
            layer.session = nil
            currentStream = nil
            return
        }

        stream.mixer.session.beginConfiguration()
        layer.session = stream.mixer.session
        orientation = stream.mixer.videoIO.orientation
        stream.mixer.session.commitConfiguration()

        stream.lockQueue.async {
            stream.mixer.videoIO.drawable = self
            self.currentStream = stream
            stream.mixer.startRunning()
        }
    }
}

extension HKView: NetStreamDrawable {
    // MARK: NetStreamDrawable
    func draw(image: CIImage) {
    }
}
