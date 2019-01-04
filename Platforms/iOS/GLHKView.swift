import AVFoundation
import GLKit

open class GLHKView: GLKView {
    static let defaultOptions: [String: AnyObject] = [
        convertFromCIContextOption(CIContextOption.workingColorSpace): NSNull(),
        convertFromCIContextOption(CIContextOption.useSoftwareRenderer): NSNumber(value: false)
    ]
    public static var defaultBackgroundColor: UIColor = .black
    open var videoGravity: AVLayerVideoGravity = .resizeAspect

    var position: AVCaptureDevice.Position = .back
    var orientation: AVCaptureVideoOrientation = .portrait

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
        delegate = self
        enableSetNeedsDisplay = true
        backgroundColor = GLHKView.defaultBackgroundColor
        layer.backgroundColor = GLHKView.defaultBackgroundColor.cgColor
    }

    open func attachStream(_ stream: NetStream?) {
        if let stream: NetStream = stream {
            stream.mixer.videoIO.context = CIContext(eaglContext: context, options: convertToOptionalCIContextOptionDictionary(GLHKView.defaultOptions))
            stream.lockQueue.async {
                self.position = stream.mixer.videoIO.position
                stream.mixer.videoIO.drawable = self
                stream.mixer.startRunning()
            }
        }
        currentStream = stream
    }
}

extension GLHKView: GLKViewDelegate {
    // MARK: GLKViewDelegate
    public func glkView(_ view: GLKView, drawIn rect: CGRect) {
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        guard let displayImage: CIImage = displayImage else {
            return
        }
        var inRect = CGRect(x: 0, y: 0, width: CGFloat(drawableWidth), height: CGFloat(drawableHeight))
        var fromRect: CGRect = displayImage.extent
        VideoGravityUtil.calculate(videoGravity, inRect: &inRect, fromRect: &fromRect)
        if position == .front {
            currentStream?.mixer.videoIO.context?.draw(displayImage.oriented(forExifOrientation: 2), in: inRect, from: fromRect)
        } else {
            currentStream?.mixer.videoIO.context?.draw(displayImage, in: inRect, from: fromRect)
        }
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

// Helper function inserted by Swift 4.2 migrator.
private func convertFromCIContextOption(_ input: CIContextOption) -> String {
	return input.rawValue
}

// Helper function inserted by Swift 4.2 migrator.
private func convertToOptionalCIContextOptionDictionary(_ input: [String: Any]?) -> [CIContextOption: Any]? {
	guard let input = input else { return nil }
	return Dictionary(uniqueKeysWithValues: input.map { key, value in (CIContextOption(rawValue: key), value) })
}
