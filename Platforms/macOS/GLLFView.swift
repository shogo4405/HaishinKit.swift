import GLUT
import OpenGL.GL3
import Foundation
import AVFoundation

public class GLLFView: NSOpenGLView {
    static let pixelFormatAttributes: [NSOpenGLPixelFormatAttribute] = [
        UInt32(NSOpenGLPFAAccelerated),
        UInt32(NSOpenGLPFANoRecovery),
        UInt32(NSOpenGLPFAColorSize), UInt32(32),
        UInt32(NSOpenGLPFAAllowOfflineRenderers),
        UInt32(0)
    ]

    override public class func defaultPixelFormat() -> NSOpenGLPixelFormat {
        guard let pixelFormat:NSOpenGLPixelFormat = NSOpenGLPixelFormat(
            attributes: GLLFView.pixelFormatAttributes) else {
            return NSOpenGLPixelFormat()
        }
        return pixelFormat
    }

    public var videoGravity:String! = AVLayerVideoGravityResizeAspect
    var orientation:AVCaptureVideoOrientation = .Portrait
    var position:AVCaptureDevicePosition = .Front
    private var displayImage:CIImage!
    private var ciContext:CIContext!
    private var originalFrame:CGRect = CGRectZero
    private var scale:CGRect = CGRectZero
    private weak var currentStream:Stream?

    public override func prepareOpenGL() {
        if let openGLContext:NSOpenGLContext = openGLContext {
            ciContext = CIContext(
                CGLContext: openGLContext.CGLContextObj,
                pixelFormat: openGLContext.pixelFormat.CGLPixelFormatObj,
                colorSpace: nil,
                options: nil
            )
            openGLContext.makeCurrentContext()
        }
        glDisable(GLenum(GL_ALPHA_TEST))
        glDisable(GLenum(GL_DEPTH_TEST))
        glDisable(GLenum(GL_BLEND))
        glDisable(GLenum(GL_DITHER))
        glDisable(GLenum(GL_CULL_FACE))
        glColorMask(GLboolean(GL_TRUE), GLboolean(GL_TRUE), GLboolean(GL_TRUE), GLboolean(GL_TRUE))
        glDepthMask(GLboolean(GL_FALSE))
        glStencilMask(0)
        glClearColor(0.0, 0.0, 0.0, 1.0)
        glClear(GLenum(GL_COLOR_BUFFER_BIT))
        glHint(GLenum(GL_TRANSFORM_HINT_APPLE), GLenum(GL_FASTEST))
        glFlush()
        originalFrame = frame
    }

    public override func drawRect(dirtyRect: NSRect) {
        guard let
            image:CIImage = displayImage,
            glContext:NSOpenGLContext = openGLContext else {
            return
        }

        var inRect:CGRect = dirtyRect
        var fromRect:CGRect = image.extent
        VideoGravityUtil.calclute(videoGravity, inRect: &inRect, fromRect: &fromRect)

        inRect.origin.x = inRect.origin.x * scale.size.width
        inRect.origin.y = inRect.origin.y * scale.size.height
        inRect.size.width = inRect.size.width * scale.size.width
        inRect.size.height = inRect.size.height * scale.size.height

        glContext.makeCurrentContext()
        glClear(GLenum(GL_COLOR_BUFFER_BIT))
        ciContext.drawImage(image, inRect: inRect.integral, fromRect: fromRect)

        glFlush()
    }

    override public func reshape() {
        let rect:CGRect = frame
        scale = CGRectMake(0, 0, originalFrame.size.width / rect.size.width, originalFrame.size.height / rect.size.height)
        glViewport(0, 0, Int32(rect.width), Int32(rect.height))
        glMatrixMode(GLenum(GL_PROJECTION))
        glLoadIdentity()
        glOrtho(0, GLdouble(rect.size.width), 0, GLdouble(rect.size.height), -1, 1)
        glMatrixMode(GLenum(GL_MODELVIEW))
        glLoadIdentity()
    }

    public func attachStream(stream: Stream?) {
        if let currentStream:Stream = currentStream {
            currentStream.mixer.videoIO.drawable = nil
        }
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
            self.needsDisplay = true
        }
    }
}
