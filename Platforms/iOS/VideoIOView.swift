import GLKit
import Foundation
import AVFoundation

public class VideoIOView: GLKView {

    public var videoGravity:String! = AVLayerVideoGravityResizeAspectFill
    var ciContext:CIContext!

    init() {
        super.init(frame: CGRectZero, context: EAGLContext(API: .OpenGLES2))
        ciContext = CIContext(EAGLContext: context)
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func drawImage(image:CIImage) {
        bindDrawable()
        if (context != EAGLContext.currentContext()) {
            EAGLContext.setCurrentContext(context)
        }
        var inRect:CGRect = CGRectMake(0, 0, CGFloat(drawableWidth), CGFloat(drawableHeight))
        var fromRect:CGRect = image.extent
        VideoGravityUtil.calclute(videoGravity, inRect: &inRect, fromRect: &fromRect)
        ciContext.drawImage(image, inRect: inRect, fromRect: image.extent)
        display()
    }
}
