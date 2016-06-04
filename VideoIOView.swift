import GLUT
import OpenGL.GL3
import Foundation
import AVFoundation

public class VideoIOView: NSOpenGLView {
    static let pixelFormatAttributes: [NSOpenGLPixelFormatAttribute] = [
        UInt32(NSOpenGLPFAAccelerated),
        UInt32(NSOpenGLPFANoRecovery),
        UInt32(NSOpenGLPFAColorSize), UInt32(32),
        UInt32(NSOpenGLPFAAllowOfflineRenderers),
        UInt32(0)
    ]

    private var context:CIContext!
    private var displayImage:CIImage!

    init() {
        let pixelFormat:NSOpenGLPixelFormat = NSOpenGLPixelFormat(attributes: VideoIOView.pixelFormatAttributes)!
        super.init(frame: NSZeroRect, pixelFormat: pixelFormat)!
        context = CIContext(
            CGLContext: openGLContext!.CGLContextObj,
            pixelFormat: pixelFormat.CGLPixelFormatObj,
            colorSpace: nil,
            options: nil
        )
    }

    required public init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    public override func prepareOpenGL() {
        var param:GLint = 1;
        openGLContext?.setValues(&param, forParameter: .GLCPSwapInterval)
        glDisable(UInt32(GL_ALPHA_TEST))
        glDisable(UInt32(GL_DEPTH_TEST))
        glDisable(UInt32(GL_SCISSOR_TEST))
        glDisable(UInt32(GL_BLEND))
        glDisable(UInt32(GL_DITHER))
        glDisable(UInt32(GL_CULL_FACE))
        glColorMask(UInt8(GL_TRUE), UInt8(GL_TRUE), UInt8(GL_TRUE), UInt8(GL_TRUE))
        glDepthMask(UInt8(GL_FALSE))
        glStencilMask(0)
        glClearColor(0.0, 0.0, 0.0, 0.0);
        glHint(UInt32(GL_TRANSFORM_HINT_APPLE), UInt32(GL_FASTEST))
    }

    public override func drawRect(dirtyRect: NSRect) {
        guard let image:CIImage = displayImage else {
            return
        }

        let integral:CGRect = CGRectIntegral(dirtyRect)
        let inset:CGRect = CGRectIntersection(CGRectInset(integral, -1.0, -1.0), frame)
        openGLContext!.makeCurrentContext()

        glClearColor(0.0, 0.0, 0.0, 0.0)
        glClear(GLenum(GL_COLOR_BUFFER_BIT));

        glScissor(Int32(integral.origin.x), Int32(integral.origin.y), Int32(integral.size.width), Int32(integral.size.height))
        glBlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA))
        glEnable(GLenum(GL_BLEND))
        context.drawImage(image, inRect: inset, fromRect: image.extent)
        glDisable(GLenum(GL_BLEND))

        glFlush()
    }

    override public func reshape() {
        let rect:CGRect = self.frame
        glViewport(0, 0, Int32(rect.width), Int32(rect.height))
        glMatrixMode(UInt32(GL_PROJECTION))
        glLoadIdentity()
        glOrtho(0, Double(rect.size.width), 0, Double(rect.size.height), -1, 1);
        glMatrixMode(UInt32(GL_MODELVIEW))
        glLoadIdentity()
    }

    func render(image:CIImage) {
        displayImage = image
        dispatch_async(dispatch_get_main_queue()) {
            self.needsDisplay = true
        }
    }
}
