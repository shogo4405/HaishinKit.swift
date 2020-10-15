import AVFoundation
import MetalKit

/**
  A view that displays a video content of a NetStream object which uses Metal api.
 */
open class MTHKView: MTKView, NetStreamRenderer {
    open var isMirrored: Bool = false
    /// A value that specifies how the video is displayed within a player layer’s bounds.
    open var videoGravity: AVLayerVideoGravity = .resizeAspect
    /// A value that displays a video format.
    open var videoFormatDescription: CMVideoFormatDescription? {
        currentStream?.mixer.videoIO.formatDescription
    }

    #if !os(tvOS)
    var position: AVCaptureDevice.Position = .back
    var orientation: AVCaptureVideoOrientation = .portrait
    #endif

    var displayImage: CIImage?
    let colorSpace: CGColorSpace = CGColorSpaceCreateDeviceRGB()
    private weak var currentStream: NetStream? {
        didSet {
            oldValue?.mixer.videoIO.renderer = nil
            if let currentStream = currentStream {
                currentStream.mixer.videoIO.context = CIContext(mtlDevice: device!)
                currentStream.lockQueue.async {
                    currentStream.mixer.videoIO.renderer = self
                    currentStream.mixer.startRunning()
                }
            }
        }
    }

    public init(frame: CGRect) {
        super.init(frame: frame, device: MTLCreateSystemDefaultDevice())
        awakeFromNib()
    }

    public required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.device = MTLCreateSystemDefaultDevice()
    }

    override open func awakeFromNib() {
        super.awakeFromNib()
        delegate = self
        framebufferOnly = false
        enableSetNeedsDisplay = true
    }

    /// Attaches a view to a new NetStream object.
    open func attachStream(_ stream: NetStream?) {
        if Thread.isMainThread {
            currentStream = stream
        } else {
            DispatchQueue.main.async {
                self.currentStream = stream
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
            let commandBuffer = device?.makeCommandQueue()?.makeCommandBuffer(),
            let context = currentStream?.mixer.videoIO.context else {
            return
        }
        if
            let currentRenderPassDescriptor = currentRenderPassDescriptor,
            let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: currentRenderPassDescriptor) {
            renderCommandEncoder.endEncoding()
        }
        guard let displayImage = displayImage else {
            commandBuffer.present(currentDrawable)
            commandBuffer.commit()
            return
        }
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
            .transformed(by: CGAffineTransform(translationX: translationX, y: translationY))
            .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        if isMirrored {
            if #available(iOS 11.0, tvOS 11.0, macOS 10.13, *) {
                scaledImage = scaledImage.oriented(.upMirrored)
            } else {
                scaledImage = scaledImage.oriented(forExifOrientation: 2)
            }
        }

        context.render(scaledImage, to: currentDrawable.texture, commandBuffer: commandBuffer, bounds: bounds, colorSpace: colorSpace)
        commandBuffer.present(currentDrawable)
        commandBuffer.commit()
    }
}
