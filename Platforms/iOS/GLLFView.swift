import GLKit
import Foundation
import AVFoundation

open class GLLFView: GLKView {
    static let defaultOptions:[String: AnyObject] = [
        kCIContextWorkingColorSpace: NSNull()
    ]
    open static var defaultBackgroundColor:UIColor = UIColor.black

    open var videoGravity:String = AVLayerVideoGravityResizeAspect

    var orientation:AVCaptureVideoOrientation = .portrait
    var position:AVCaptureDevicePosition = .front {
        didSet {
            switch position {
            case .front:
                transform = transform.scaledBy(x: -1, y: 1)
            case .back:
                transform = CGAffineTransform.identity
            default:
                break
            }
        }
    }

    fileprivate var ciContext:CIContext!
    fileprivate var displayImage:CIImage?
    fileprivate weak var currentStream:NetStream? {
        didSet {
            guard let oldValue:NetStream = oldValue else {
                return
            }
            oldValue.mixer.videoIO.drawable = nil
        }
    }

    public override init(frame: CGRect) {
        super.init(frame: frame, context: EAGLContext(api: .openGLES2))
        awakeFromNib()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    open override func awakeFromNib() {
        enableSetNeedsDisplay = true
        backgroundColor = GLLFView.defaultBackgroundColor
        layer.backgroundColor = GLLFView.defaultBackgroundColor.cgColor
        ciContext = CIContext(eaglContext: context, options: GLLFView.defaultOptions)
    }

    open override func draw(_ rect: CGRect) {
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        guard let displayImage:CIImage = displayImage else {
            return
        }
        var inRect:CGRect = CGRect(x: 0, y: 0, width: CGFloat(drawableWidth), height: CGFloat(drawableHeight))
        var fromRect:CGRect = displayImage.extent
        VideoGravityUtil.calclute(videoGravity, inRect: &inRect, fromRect: &fromRect)
        ciContext.draw(displayImage, in: inRect, from: fromRect)
    }

    open func attachStream(_ stream:NetStream?) {
        if let stream:NetStream = stream {
            stream.mixer.videoIO.drawable = self
        }
        currentStream = stream
    }
}

// MARK: - StreamDrawable
extension GLLFView: NetStreamDrawable {
    func render(image: CIImage, to toCVPixelBuffer: CVPixelBuffer) {
        ciContext.render(image, to: toCVPixelBuffer)
    }
    func draw(image:CIImage) {
        displayImage = image
        DispatchQueue.main.async {
            self.setNeedsDisplay()
        }
    }
}
