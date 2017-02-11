import UIKit
import Foundation
import AVFoundation

open class LFView: UIView {
    open static var defaultBackgroundColor:UIColor = UIColor.black

    open override class var layerClass:AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }

    open override var layer:AVCaptureVideoPreviewLayer {
        return super.layer as! AVCaptureVideoPreviewLayer
    }

    public var videoGravity:String = AVLayerVideoGravityResizeAspect {
        didSet {
            layer.videoGravity = videoGravity
        }
    }

    var orientation:AVCaptureVideoOrientation = .portrait {
        didSet {
            guard let connection:AVCaptureConnection = layer.connection else {
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

    deinit {
        attachStream(nil)
    }

    override open func awakeFromNib() {
        backgroundColor = LFView.defaultBackgroundColor
        layer.backgroundColor = LFView.defaultBackgroundColor.cgColor
    }

    open func attachStream(_ stream:NetStream?) {
        guard let stream:NetStream = stream else {
            layer.session = nil
            currentStream = nil
            return
        }
        stream.lockQueue.async {
            stream.mixer.session.beginConfiguration()
            self.layer.session = stream.mixer.session
            stream.mixer.videoIO.drawable = self
            self.orientation = stream.mixer.videoIO.orientation
            self.currentStream = stream
            stream.mixer.session.commitConfiguration()
            stream.mixer.startRunning()
        }
    }
}

extension LFView: NetStreamDrawable {
    // MARK: NetStreamDrawable
    func draw(image:CIImage) {
    }
    func render(image: CIImage, to toCVPixelBuffer: CVPixelBuffer) {
    }
}
