import GLUT
import OpenGL.GL3
import Foundation
import AVFoundation

open class GLLFView: NSOpenGLView {
    static let pixelFormatAttributes: [NSOpenGLPixelFormatAttribute] = [
        UInt32(NSOpenGLPFAAccelerated),
        UInt32(NSOpenGLPFANoRecovery),
        UInt32(NSOpenGLPFAColorSize), UInt32(32),
        UInt32(NSOpenGLPFAAllowOfflineRenderers),
        UInt32(0)
    ]

    override open class func defaultPixelFormat() -> NSOpenGLPixelFormat {
        guard let pixelFormat:NSOpenGLPixelFormat = NSOpenGLPixelFormat(
            attributes: GLLFView.pixelFormatAttributes) else {
            return NSOpenGLPixelFormat()
        }
        return pixelFormat
    }

    public var videoGravity:AVLayerVideoGravity = .resizeAspect
    var orientation:AVCaptureVideoOrientation = .portrait
    var position:AVCaptureDevice.Position = .front
    private var displayImage:CIImage!
    private var originalFrame:CGRect = CGRect.zero
    private var scale:CGRect = CGRect.zero
    private weak var currentStream:NetStream?

    open override func prepareOpenGL() {
        var param:GLint = 1
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

    open override func draw(_ dirtyRect: NSRect) {
        guard
            let image:CIImage = displayImage,
            let glContext:NSOpenGLContext = openGLContext else {
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
        currentStream?.mixer.videoIO.context?.draw(image, in: inRect.integral, from: fromRect)

        glFlush()
    }

    override open func reshape() {
        let rect:CGRect = frame
        scale = CGRect(x: 0, y: 0, width: originalFrame.size.width / rect.size.width, height: originalFrame.size.height / rect.size.height)
        glViewport(0, 0, Int32(rect.width), Int32(rect.height))
        glMatrixMode(GLenum(GL_PROJECTION))
        glLoadIdentity()
        glOrtho(0, GLdouble(rect.size.width), 0, GLdouble(rect.size.height), -1, 1)
        glMatrixMode(GLenum(GL_MODELVIEW))
        glLoadIdentity()
    }

    open func attachStream(_ stream: NetStream?) {
        if let currentStream:NetStream = currentStream {
            currentStream.mixer.videoIO.drawable = nil
        }
        if let stream:NetStream = stream {
            stream.lockQueue.async {
                if let openGLContext:NSOpenGLContext = self.openGLContext {
                    stream.mixer.videoIO.context = CIContext(
                        cglContext: openGLContext.cglContextObj!,
                        pixelFormat: openGLContext.pixelFormat.cglPixelFormatObj,
                        colorSpace: nil,
                        options: nil
                    )
                    openGLContext.makeCurrentContext()
                }
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
            self.needsDisplay = true
        }
    }
}
