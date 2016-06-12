import GLKit
import Foundation
import AVFoundation

public class VideoIOView: GLKView {

    public var videoGravity:String! = AVLayerVideoGravityResizeAspectFill
    var ciContext:CIContext!

    private var image:CIImage?

    init() {
        super.init(frame: CGRectZero, context: EAGLContext(API: .OpenGLES2))
        ciContext = CIContext(EAGLContext: context)
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func drawImage(image:CIImage) {
        self.image = image
        display()
    }

    public override func drawRect(rect: CGRect) {
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        guard let image:CIImage = image else {
            return
        }
        var inRect:CGRect = CGRectMake(0, 0, CGFloat(drawableWidth), CGFloat(drawableHeight))
        var fromRect:CGRect = image.extent
        if (drawable(image.extent.size)) {
            VideoGravityUtil.calclute(videoGravity, inRect: &inRect, fromRect: &fromRect)
        }
        ciContext.drawImage(image, inRect: inRect, fromRect: image.extent)
    }

    private func drawable(size:CGSize) -> Bool {
        return
            (drawableWidth < drawableHeight) && (size.width < size.height) ||
            (drawableHeight < drawableWidth) && (size.height < size.width)
    }
}
