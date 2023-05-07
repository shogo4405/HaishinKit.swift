import AVFoundation
import MetalKit

/**
 * A view that displays a video content of a NetStream object which uses Metal api.
 */
public class MTHKView: MTKView {
    public var isMirrored = false
    /// Specifies how the video is displayed within a player layer’s bounds.
    public var videoGravity: AVLayerVideoGravity = .resizeAspect

    public var videoFormatDescription: CMVideoFormatDescription? {
        currentStream?.mixer.videoIO.formatDescription
    }

    #if !os(tvOS)
    public var videoOrientation: AVCaptureVideoOrientation = .portrait
    #endif

    private var currentSampleBuffer: CMSampleBuffer?
    private let colorSpace: CGColorSpace = CGColorSpaceCreateDeviceRGB()

    private lazy var commandQueue: (any MTLCommandQueue)? = {
        return device?.makeCommandQueue()
    }()

    private weak var currentStream: NetStream? {
        didSet {
            oldValue?.mixer.videoIO.drawable = nil
            if let currentStream = currentStream {
                currentStream.mixer.videoIO.context = CIContext(mtlDevice: device!)
                currentStream.lockQueue.async {
                    currentStream.mixer.videoIO.drawable = self
                    currentStream.mixer.startRunning()
                }
            }
        }
    }

    /// Initializes and returns a newly allocated view object with the specified frame rectangle.
    public init(frame: CGRect) {
        super.init(frame: frame, device: MTLCreateSystemDefaultDevice())
        awakeFromNib()
    }

    /// Returns an object initialized from data in a given unarchiver.
    public required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.device = MTLCreateSystemDefaultDevice()
    }

    /// Prepares the receiver for service after it has been loaded from an Interface Builder archive, or nib file.
    override open func awakeFromNib() {
        super.awakeFromNib()
        delegate = self
        framebufferOnly = false
        enableSetNeedsDisplay = true
    }
}

extension MTHKView: NetStreamDrawable {
    // MARK: NetStreamDrawable
    public func attachStream(_ stream: NetStream?) {
        if Thread.isMainThread {
            currentStream = stream
        } else {
            DispatchQueue.main.async {
                self.currentStream = stream
            }
        }
    }

    public func enqueue(_ sampleBuffer: CMSampleBuffer?) {
        if Thread.isMainThread {
            currentSampleBuffer = sampleBuffer
            #if os(macOS)
            self.needsDisplay = true
            #else
            self.setNeedsDisplay()
            #endif
        } else {
            DispatchQueue.main.async {
                self.enqueue(sampleBuffer)
            }
        }
    }
}

extension MTHKView: MTKViewDelegate {
    // MARK: MTKViewDelegate
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }

    public func draw(in view: MTKView) {
        guard
            let currentDrawable = currentDrawable,
            let commandBuffer = commandQueue?.makeCommandBuffer(),
            let context = currentStream?.mixer.videoIO.context else {
            return
        }
        if
            let currentRenderPassDescriptor = currentRenderPassDescriptor,
            let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: currentRenderPassDescriptor) {
            renderCommandEncoder.endEncoding()
        }
        guard let imageBuffer = currentSampleBuffer?.imageBuffer else {
            commandBuffer.present(currentDrawable)
            commandBuffer.commit()
            return
        }
        let displayImage = CIImage(cvPixelBuffer: imageBuffer)
        var scaleX: CGFloat = 0
        var scaleY: CGFloat = 0
        var translationX: CGFloat = 0
        var translationY: CGFloat = 0
        switch videoGravity {
        case .resize:
            scaleX = drawableSize.width / displayImage.extent.width
            scaleY = drawableSize.height / displayImage.extent.height
        case .resizeAspect:
            let scale: CGFloat = min(drawableSize.width / displayImage.extent.width, drawableSize.height / displayImage.extent.height)
            scaleX = scale
            scaleY = scale
            translationX = (drawableSize.width - displayImage.extent.width * scale) / scaleX / 2
            translationY = (drawableSize.height - displayImage.extent.height * scale) / scaleY / 2
        case .resizeAspectFill:
            let scale: CGFloat = max(drawableSize.width / displayImage.extent.width, drawableSize.height / displayImage.extent.height)
            scaleX = scale
            scaleY = scale
            translationX = (drawableSize.width - displayImage.extent.width * scale) / scaleX / 2
            translationY = (drawableSize.height - displayImage.extent.height * scale) / scaleY / 2
        default:
            break
        }
        let bounds = CGRect(origin: .zero, size: drawableSize)
        var scaledImage: CIImage = displayImage

        if isMirrored {
            scaledImage = scaledImage.oriented(.upMirrored)
        }

        scaledImage = scaledImage
            .transformed(by: CGAffineTransform(translationX: translationX, y: translationY))
            .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        context.render(scaledImage, to: currentDrawable.texture, commandBuffer: commandBuffer, bounds: bounds, colorSpace: colorSpace)
        commandBuffer.present(currentDrawable)
        commandBuffer.commit()
    }
}
