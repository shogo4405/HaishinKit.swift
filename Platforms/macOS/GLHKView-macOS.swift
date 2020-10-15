#if os(macOS)
import AppKit
import AVFoundation
import GLUT
import OpenGL.GL3

/**
  A view that displays a video content of a NetStream object which uses OpenGL api. This class is deprecated. Please consider to use the MTHKView.
 */
open class GLHKView: NSOpenGLView, NetStreamRenderer {
    static let pixelFormatAttributes: [NSOpenGLPixelFormatAttribute] = [
        UInt32(NSOpenGLPFAAccelerated),
        UInt32(NSOpenGLPFANoRecovery),
        UInt32(NSOpenGLPFAColorSize), UInt32(32),
        UInt32(NSOpenGLPFAAllowOfflineRenderers),
        UInt32(0)
    ]

    override open class func defaultPixelFormat() -> NSOpenGLPixelFormat {
        guard let pixelFormat = NSOpenGLPixelFormat(
            attributes: GLHKView.pixelFormatAttributes) else {
            return NSOpenGLPixelFormat()
        }
        return pixelFormat
    }

    /// A value that specifies how the video is displayed within a player layer’s bounds.
    open var videoGravity: AVLayerVideoGravity = .resizeAspect
    /// A value that displays video format.
    open var videoFormatDescription: CMVideoFormatDescription? {
        currentStream?.mixer.videoIO.formatDescription
    }
    var position: AVCaptureDevice.Position = .front
    var orientation: AVCaptureVideoOrientation = .portrait
    var displayImage: CIImage?
    private var originalFrame: CGRect = .zero
    private var scale: CGSize = .zero
    private weak var currentStream: NetStream?

    override open func prepareOpenGL() {
        var param: GLint = 1
        openGLContext?.setValues(&param, for: .swapInterval)
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

    override open func draw(_ dirtyRect: NSRect) {
        guard
            let image: CIImage = displayImage,
            let glContext: NSOpenGLContext = openGLContext else {
            return
        }

        var inRect: CGRect = dirtyRect
        var fromRect: CGRect = image.extent
        VideoGravityUtil.calculate(videoGravity, inRect: &inRect, fromRect: &fromRect)

        inRect.origin.x *= scale.width
        inRect.origin.y *= scale.height
        inRect.size.width *= scale.width
        inRect.size.height *= scale.height

        glContext.makeCurrentContext()
        glClear(GLenum(GL_COLOR_BUFFER_BIT))
        currentStream?.mixer.videoIO.context?.draw(image, in: inRect.integral, from: fromRect)

        glFlush()
    }

    override open func reshape() {
        let rect: CGRect = frame
        scale = CGSize(width: originalFrame.size.width / rect.size.width, height: originalFrame.size.height / rect.size.height)
        glViewport(0, 0, Int32(rect.width), Int32(rect.height))
        glMatrixMode(GLenum(GL_PROJECTION))
        glLoadIdentity()
        glOrtho(0, GLdouble(rect.size.width), 0, GLdouble(rect.size.height), -1, 1)
        glMatrixMode(GLenum(GL_MODELVIEW))
        glLoadIdentity()
    }

    /// Attaches a view to a new NetStream object.
    open func attachStream(_ stream: NetStream?) {
        if let currentStream: NetStream = currentStream {
            currentStream.mixer.videoIO.renderer = nil
        }
        if let stream: NetStream = stream {
            stream.lockQueue.async {
                if let openGLContext: NSOpenGLContext = self.openGLContext {
                    stream.mixer.videoIO.context = CIContext(
                        cglContext: openGLContext.cglContextObj!,
                        pixelFormat: openGLContext.pixelFormat.cglPixelFormatObj,
                        colorSpace: nil,
                        options: nil
                    )
                    openGLContext.makeCurrentContext()
                }
                stream.mixer.videoIO.renderer = self
                stream.mixer.startRunning()
            }
        }
        currentStream = stream
    }
}

#endif
