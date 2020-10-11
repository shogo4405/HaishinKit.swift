#if os(iOS) || os(tvOS)

import AVFoundation
import GLKit

/**
  A view that displays a video content of a NetStream object which uses OpenGL api. This class is deprecated. Please consider to use the MTHKView.
 */
open class GLHKView: GLKView, NetStreamRenderer {
    static let defaultOptions: [CIContextOption: Any] = [
        .workingColorSpace: NSNull(),
        .useSoftwareRenderer: NSNumber(value: false)
    ]
    public static var defaultBackgroundColor: UIColor = .black

    open var isMirrored: Bool = false
    /// A value that specifies how the video is displayed within a player layer’s bounds.
    open var videoGravity: AVLayerVideoGravity = .resizeAspect
    /// A value that displays a video format.
    open var videoFormatDescription: CMVideoFormatDescription? {
        currentStream?.mixer.videoIO.formatDescription
    }

    var displayImage: CIImage?
    #if !os(tvOS)
    var position: AVCaptureDevice.Position = .back
    var orientation: AVCaptureVideoOrientation = .portrait
    #endif

    private weak var currentStream: NetStream? {
        didSet {
            oldValue?.mixer.videoIO.renderer = nil
            if let currentStream = currentStream {
                currentStream.mixer.videoIO.context = CIContext(eaglContext: context, options: GLHKView.defaultOptions)
                currentStream.lockQueue.async {
                    #if !os(tvOS)
                    self.position = currentStream.mixer.videoIO.position
                    #endif
                    currentStream.mixer.videoIO.renderer = self
                    currentStream.mixer.startRunning()
                }
            }
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

    /// Attaches a view to a new NetStream object.
    open func attachStream(_ stream: NetStream?) {
        if Thread.isMainThread {
            currentStream = stream
        } else {
            DispatchQueue.main.async {
                self.currentStream = stream
            }
        }
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
            if #available(iOS 11.0, tvOS 11.0, *) {
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
