import GLKit
import Foundation
import AVFoundation

public class VideoIOView: GLKView {
    static let defaultOptions:[String: AnyObject] = [
        kCIContextWorkingColorSpace: NSNull()
    ]
    static var defaultBackgroundColor:UIColor = UIColor.blackColor()

    public var videoGravity:String! = AVLayerVideoGravityResize {
        didSet {
            switch videoGravity {
            case AVLayerVideoGravityResizeAspect:
                layer.contentsGravity = kCAGravityResizeAspect
            case AVLayerVideoGravityResizeAspectFill:
                layer.contentsGravity = kCAGravityResizeAspectFill
            case AVLayerVideoGravityResize:
                layer.contentsGravity = kCAGravityResize
            default:
                layer.contentsGravity = kCAGravityResizeAspect
            }
        }
    }

    var ciContext:CIContext!

    private var image:CIImage?

    init() {
        super.init(frame: CGRectZero, context: EAGLContext(API: .OpenGLES2))
        enableSetNeedsDisplay = true
        backgroundColor = VideoIOView.defaultBackgroundColor
        layer.backgroundColor = VideoIOView.defaultBackgroundColor.CGColor
        ciContext = CIContext(EAGLContext: context, options: VideoIOView.defaultOptions)
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func drawRect(rect: CGRect) {
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        guard let image:CIImage = image else {
            return
        }
        let inRect:CGRect = CGRectMake(0, 0, CGFloat(drawableWidth), CGFloat(drawableHeight))
        ciContext.drawImage(image, inRect: inRect, fromRect: image.extent)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        setNeedsDisplay()
    }

    func drawImage(image:CIImage) {
        self.image = image
        dispatch_async(dispatch_get_main_queue()) {
            self.setNeedsDisplay()
        }
    }
}
