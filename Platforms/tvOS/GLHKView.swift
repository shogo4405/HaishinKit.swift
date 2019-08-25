import AVFoundation
import GLKit

open class GLHKView: GLKView {
    static let defaultOptions: [CIContextOption: Any] = [
        .workingColorSpace: NSNull(),
        .useSoftwareRenderer: NSNumber(value: false)
    ]
    public static var defaultBackgroundColor: UIColor = .black

    open var videoGravity: AVLayerVideoGravity = .resizeAspect
    private var displayImage: CIImage?
    private weak var currentStream: NetStream? {
        didSet {
            oldValue?.mixer.videoIO.drawable = nil
        }
    }

    override public init(frame: CGRect) {
        super.init(frame: frame, context: EAGLContext(api: .openGLES2)!)
        awakeFromNib()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.context = EAGLContext(api: .openGLES2)!
    }

    override open func awakeFromNib() {
        super.awakeFromNib()
        enableSetNeedsDisplay = true
        backgroundColor = GLHKView.defaultBackgroundColor
        layer.backgroundColor = GLHKView.defaultBackgroundColor.cgColor
    }

    override open func draw(_ rect: CGRect) {
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        guard let displayImage: CIImage = displayImage else {
            return
        }
        var inRect = CGRect(x: 0, y: 0, width: CGFloat(drawableWidth), height: CGFloat(drawableHeight))
        var fromRect: CGRect = displayImage.extent
        VideoGravityUtil.calculate(videoGravity, inRect: &inRect, fromRect: &fromRect)
        currentStream?.mixer.videoIO.context?.draw(displayImage, in: inRect, from: fromRect)
    }

    open func attachStream(_ stream: NetStream?) {
        if let stream: NetStream = stream {
            stream.lockQueue.async {
                stream.mixer.videoIO.context = CIContext(eaglContext: self.context, options: GLHKView.defaultOptions)
                stream.mixer.videoIO.drawable = self
                stream.mixer.startRunning()
            }
        }
        currentStream = stream
    }
}

extension GLHKView: NetStreamDrawable {
    // MARK: NetStreamDrawable
    func draw(image: CIImage) {
        DispatchQueue.main.async {
            self.displayImage = image
            self.setNeedsDisplay()
        }
    }
}
