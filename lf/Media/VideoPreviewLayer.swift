import AVFoundation

final class VideoPreviewLayer: AVCaptureVideoPreviewLayer {
    var surface:CALayer = CALayer()

    var enabledSurface:Bool = false {
        didSet{
            guard enabledSurface != oldValue else {
                return
            }
            if (enabledSurface) {
                surface.contents = nil
                surface.frame = frame
                addSublayer(surface)
                return
            }
            surface.removeFromSuperlayer()
        }
    }

    override var transform:CATransform3D {
        get {
            return surface.transform
        }
        set {
            surface.transform = newValue
        }
    }

    override var frame:CGRect {
        get {
            return super.frame
        }
        set {
            super.frame = newValue
            surface.frame = newValue
        }
    }

    override var contents:AnyObject? {
        get {
            return surface.contents
        }
        set {
            surface.contents = newValue
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

