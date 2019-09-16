#if canImport(MetalKit)
import AVFoundation
import MetalKit

@available(iOS 9.0, *)
open class MTHKView: MTKView {
    public var videoGravity: AVLayerVideoGravity = .resizeAspect

    var position: AVCaptureDevice.Position = .back
    var orientation: AVCaptureVideoOrientation = .portrait

    var displayImage: CIImage?
    weak var currentStream: NetStream? {
        didSet {
            oldValue?.mixer.videoIO.drawable = nil
        }
    }
    let colorSpace: CGColorSpace = CGColorSpaceCreateDeviceRGB()

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

    open func attachStream(_ stream: NetStream?) {
        if let stream: NetStream = stream {
            stream.mixer.videoIO.context = CIContext(mtlDevice: device!)
            stream.lockQueue.async {
                stream.mixer.videoIO.drawable = self
                stream.mixer.startRunning()
            }
        }
        currentStream = stream
    }
}

@available(iOS 9.0, *)
extension MTHKView: MTKViewDelegate {
    // MARK: MTKViewDelegate
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }

    #if arch(i386) || arch(x86_64)
    public func draw(in view: MTKView) {
        // iOS Simulator doesn't support currentDrawable as CAMetalDrawable.
    }
    #else
    public func draw(in view: MTKView) {
        guard
            let drawable: CAMetalDrawable = currentDrawable,
            let image: CIImage = displayImage,
            let commandBuffer: MTLCommandBuffer = device?.makeCommandQueue()?.makeCommandBuffer(),
            let context: CIContext = currentStream?.mixer.videoIO.context else {
                return
        }
        var scaleX: CGFloat = 0
        var scaleY: CGFloat = 0
        var translationX: CGFloat = 0
        var translationY: CGFloat = 0
        switch videoGravity {
        case .resize:
            scaleX = drawableSize.width / image.extent.width
            scaleY = drawableSize.height / image.extent.height
        case .resizeAspect:
            let scale: CGFloat = min(drawableSize.width / image.extent.width, drawableSize.height / image.extent.height)
            scaleX = scale
            scaleY = scale
            translationX = (drawableSize.width - image.extent.width * scale) / scaleX / 2
            translationY = (drawableSize.height - image.extent.height * scale) / scaleY / 2
        case .resizeAspectFill:
            let scale: CGFloat = max(drawableSize.width / image.extent.width, drawableSize.height / image.extent.height)
            scaleX = scale
            scaleY = scale
            translationX = (drawableSize.width - image.extent.width * scale) / scaleX / 2
            translationY = (drawableSize.height - image.extent.height * scale) / scaleY / 2
        default:
            break
        }
        let bounds = CGRect(origin: .zero, size: drawableSize)
        let scaledImage: CIImage = image
            .transformed(by: CGAffineTransform(translationX: translationX, y: translationY))
            .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        context.render(scaledImage, to: drawable.texture, commandBuffer: commandBuffer, bounds: bounds, colorSpace: colorSpace)
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    #endif
}

@available(iOS 9.0, *)
extension MTHKView: NetStreamDrawable {
    // MARK: NetStreamDrawable
    func draw(image: CIImage) {
        DispatchQueue.main.async {
            self.displayImage = image
            self.setNeedsDisplay()
        }
    }
}
#endif
