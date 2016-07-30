import GLKit
import Foundation
import AVFoundation

public class GLLFView: GLKView {
    static let defaultOptions:[String: AnyObject] = [
        kCIContextWorkingColorSpace: NSNull()
    ]
    public static var defaultBackgroundColor:UIColor = UIColor.blackColor()

    public var videoGravity:String = AVLayerVideoGravityResizeAspect

    var orientation:AVCaptureVideoOrientation = .Portrait
    var position:AVCaptureDevicePosition = .Front {
        didSet {
            switch position {
            case .Front:
                transform = CGAffineTransformScale(transform, -1, 1)
            case .Back:
                transform = CGAffineTransformIdentity
            default:
                break
            }
        }
    }

    private var ciContext:CIContext!
    private var displayImage:CIImage?
    private weak var currentStream:Stream? {
        didSet {
            guard let oldValue:Stream = oldValue else {
                return
            }
            oldValue.mixer.videoIO.drawable = nil
        }
    }

    public override init(frame: CGRect) {
        super.init(frame: frame, context: EAGLContext(API: .OpenGLES2))
        awakeFromNib()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    public override func awakeFromNib() {
        enableSetNeedsDisplay = true
        backgroundColor = GLLFView.defaultBackgroundColor
        layer.backgroundColor = GLLFView.defaultBackgroundColor.CGColor
        ciContext = CIContext(EAGLContext: context, options: GLLFView.defaultOptions)
    }

    public override func drawRect(rect: CGRect) {
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        guard let displayImage:CIImage = displayImage else {
            return
        }
        var inRect:CGRect = CGRectMake(0, 0, CGFloat(drawableWidth), CGFloat(drawableHeight))
        var fromRect:CGRect = displayImage.extent
        VideoGravityUtil.calclute(videoGravity, inRect: &inRect, fromRect: &fromRect)
        ciContext.drawImage(displayImage, inRect: inRect, fromRect: fromRect)
    }

    public func attachStream(stream:Stream?) {
        if let stream:Stream = stream {
            stream.mixer.videoIO.drawable = self
        }
        currentStream = stream
    }
}

// MARK: - StreamDrawable
extension GLLFView: StreamDrawable {
    func render(image: CIImage, toCVPixelBuffer: CVPixelBuffer) {
        ciContext.render(image, toCVPixelBuffer: toCVPixelBuffer)
    }
    func drawImage(image:CIImage) {
        displayImage = image
        dispatch_async(dispatch_get_main_queue()) {
            self.setNeedsDisplay()
        }
    }
}
