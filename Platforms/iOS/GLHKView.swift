#if os(iOS)

import AVFoundation
import GLKit

open class GLHKView: GLKView, NetStreamRenderer {
    static let defaultOptions: [CIContextOption: Any] = [
        .workingColorSpace: NSNull(),
        .useSoftwareRenderer: NSNumber(value: false)
    ]
    public static var defaultBackgroundColor: UIColor = .black
    open var videoGravity: AVLayerVideoGravity = .resizeAspect
    public var videoFormatDescription: CMVideoFormatDescription? {
        currentStream?.mixer.videoIO.formatDescription
    }
    var position: AVCaptureDevice.Position = .back
    var orientation: AVCaptureVideoOrientation = .portrait
    open var isMirrored: Bool = false
    var displayImage: CIImage?
    private weak var currentStream: NetStream? {
        didSet {
            oldValue?.mixer.videoIO.renderer = nil
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
            stream.mixer.videoIO.context = CIContext(eaglContext: context, options: GLHKView.defaultOptions)
            stream.lockQueue.async {
                self.position = stream.mixer.videoIO.position
                stream.mixer.videoIO.renderer = self
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
        guard var displayImage: CIImage = displayImage else {
            return
        }
        var inRect = CGRect(x: 0, y: 0, width: CGFloat(drawableWidth), height: CGFloat(drawableHeight))
        var fromRect: CGRect = displayImage.extent

        if isMirrored {
            if #available(iOS 11.0, *) {
                displayImage = displayImage.oriented(.upMirrored)
            } else {
                displayImage = displayImage.oriented(forExifOrientation: 2)
            }
        }

        VideoGravityUtil.calculate(videoGravity, inRect: &inRect, fromRect: &fromRect)
        currentStream?.mixer.videoIO.context?.draw(displayImage, in: inRect, from: fromRect)
    }
}

#endif
