import AVFoundation

final class VideoPreviewLayer: AVCaptureVideoPreviewLayer {
    var surface:CALayer = CALayer()

    var enabledSurface:Bool = false {
        didSet{
            guard enabledSurface != oldValue else {
                return
            }
            if (enabledSurface) {
                surface.frame = frame
                addSublayer(surface)
                return
            }
            surface.removeFromSuperlayer()
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
                surface.contentsGravity = kCAGravityResizeAspect
            case AVLayerVideoGravityResizeAspectFill:
                surface.contentsGravity = kCAGravityResizeAspectFill
            case AVLayerVideoGravityResize:
                surface.contentsGravity = kCAGravityResize
            default:
                surface.contentsGravity = kCAGravityResizeAspect
            }
        }
    }
}

