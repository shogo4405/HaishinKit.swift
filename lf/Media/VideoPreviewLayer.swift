import AVFoundation

final class VideoPreviewLayer: AVCaptureVideoPreviewLayer {
    var image:CALayer = CALayer()
    private var currentSession:AVCaptureSession!

    var useCIContext:Bool = false {
        didSet{
            guard useCIContext != oldValue else {
                return
            }
            if (useCIContext) {
                currentSession = session
                image.frame = frame
                addSublayer(image)
                session = nil
                return
            }
            session = currentSession
            image.removeFromSuperlayer()
            currentSession = nil
        }
    }

    override var videoGravity:String! {
        get {
            return super.videoGravity
        }
        set {
            super.videoGravity = newValue
            switch newValue {
            case AVLayerVideoGravityResizeAspect:
                image.contentsGravity = kCAGravityResizeAspect
            case AVLayerVideoGravityResizeAspectFill:
                image.contentsGravity = kCAGravityResizeAspectFill
            case AVLayerVideoGravityResize:
                image.contentsGravity = kCAGravityResize
            default:
                image.contentsGravity = kCAGravityResizeAspect
            }
        }
    }
}

