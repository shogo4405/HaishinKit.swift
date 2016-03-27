import AVFoundation

final class VideoIOLayer: AVCaptureVideoPreviewLayer {
    private(set) var currentFPS:Int = 0

    private var timer:NSTimer?
    private var frameCount:Int = 0
    private var surface:CALayer = CALayer()

    override init() {
        super.init()
        initialize()
    }

    override init!(session: AVCaptureSession!) {
        super.init(session: session)
        initialize()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialize()
    }

    deinit {
        timer?.invalidate()
        timer = nil
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
            frameCount += 1
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

    private func initialize() {
        timer = NSTimer.scheduledTimerWithTimeInterval(
            1.0, target: self, selector: #selector(VideoIOLayer.didTimerInterval(_:)), userInfo: nil, repeats: true
        )
        addSublayer(surface)
    }

    func didTimerInterval(timer:NSTimer) {
        currentFPS = frameCount
        frameCount = 0
    }
}

