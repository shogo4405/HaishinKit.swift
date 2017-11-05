import GLKit
import Foundation
import AVFoundation

open class GLLFView: GLKView {
    static let defaultOptions:[String: AnyObject] = [
        kCIContextWorkingColorSpace: NSNull(),
        kCIContextUseSoftwareRenderer: NSNumber(value: false),
    ]
    open static var defaultBackgroundColor:UIColor = .black
    open var videoGravity:AVLayerVideoGravity = .resizeAspect
    private var displayImage:CIImage?
    private weak var currentStream:NetStream? {
        didSet {
            guard let oldValue:NetStream = oldValue else {
                return
            }
            oldValue.mixer.videoIO.drawable = nil
        }
    }

    public override init(frame: CGRect) {
        super.init(frame: frame, context: EAGLContext(api: .openGLES2)!)
        awakeFromNib()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.context = EAGLContext(api: .openGLES2)!
    }

    open override func awakeFromNib() {
        enableSetNeedsDisplay = true
        backgroundColor = GLLFView.defaultBackgroundColor
        layer.backgroundColor = GLLFView.defaultBackgroundColor.cgColor
    }

    open override func draw(_ rect: CGRect) {
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        guard let displayImage:CIImage = displayImage else {
            return
        }
        var inRect:CGRect = CGRect(x: 0, y: 0, width: CGFloat(drawableWidth), height: CGFloat(drawableHeight))
        var fromRect:CGRect = displayImage.extent
        VideoGravityUtil.calclute(videoGravity, inRect: &inRect, fromRect: &fromRect)
        currentStream?.mixer.videoIO.context?.draw(displayImage, in: inRect, from: fromRect)
    }

    open func attachStream(_ stream:NetStream?) {
        if let stream:NetStream = stream {
            stream.lockQueue.async {
                stream.mixer.videoIO.drawable = self
                stream.mixer.startRunning()
            }
        }
        currentStream = stream
    }
}

extension GLLFView: NetStreamDrawable {
    // MARK: NetStreamDrawable
    func draw(image:CIImage) {
        DispatchQueue.main.async {
            self.displayImage = image
            self.setNeedsDisplay()
        }
    }
}
