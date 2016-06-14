import GLKit
import Foundation
import AVFoundation

public class VideoIOView: GLKView {

    public var videoGravity:String! = AVLayerVideoGravityResizeAspect
    var ciContext:CIContext!

    private var image:CIImage?

    init() {
        super.init(frame: CGRectZero, context: EAGLContext(API: .OpenGLES2))
        enableSetNeedsDisplay = true
        ciContext = CIContext(EAGLContext: context)
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func drawRect(rect: CGRect) {
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        guard let image:CIImage = image else {
            return
        }
        var inRect:CGRect = CGRectMake(0, 0, CGFloat(drawableWidth), CGFloat(drawableHeight))
        var fromRect:CGRect = image.extent
        VideoGravityUtil.calclute(videoGravity, inRect: &inRect, fromRect: &fromRect)
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
