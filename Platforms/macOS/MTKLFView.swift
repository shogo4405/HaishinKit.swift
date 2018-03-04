import MetalKit
import Foundation
import AVFoundation

open class MTKLFView: MTKView {
    open var videoGravity: AVLayerVideoGravity = .resizeAspect

    var position: AVCaptureDevice.Position = .back
    var orientation: AVCaptureVideoOrientation = .portrait

    private var displayImage: CIImage?
    private weak var currentStream: NetStream? {
        didSet {
            guard let oldValue: NetStream = oldValue else {
                return
            }
            oldValue.mixer.videoIO.drawable = nil
        }
    }
    private let colorSpace: CGColorSpace = CGColorSpaceCreateDeviceRGB()

    public init(frame: CGRect) {
        super.init(frame: frame, device: MTLCreateSystemDefaultDevice())
    }

    required public init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.device = MTLCreateSystemDefaultDevice()
    }

    open override func awakeFromNib() {
        delegate = self
        enableSetNeedsDisplay = true
    }

    open func attachStream(_ stream: NetStream?) {
        if let stream: NetStream = stream {
            stream.mixer.videoIO.context = CIContext(mtlDevice: device!)
            stream.lockQueue.async {
                self.position = stream.mixer.videoIO.position
                stream.mixer.videoIO.drawable = self
                stream.mixer.startRunning()
            }
        }
        currentStream = stream
    }
}

extension MTKLFView: MTKViewDelegate {
    // MARK: MTKViewDelegate
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }

    public func draw(in view: MTKView) {
        guard
            let drawable: CAMetalDrawable = currentDrawable,
            let image: CIImage = displayImage,
            let commandBuffer: MTLCommandBuffer = device?.makeCommandQueue()?.makeCommandBuffer(),
            let context: CIContext = currentStream?.mixer.videoIO.context else {
            return
        }
        let bounds: CGRect = CGRect(origin: CGPoint.zero, size: drawableSize)
        let scaleX: CGFloat = drawableSize.width / image.extent.width
        let scaleY: CGFloat = drawableSize.height / image.extent.height
        let scale: CGFloat = min(scaleX, scaleY)
        let translationX: CGFloat = (drawableSize.width - image.extent.width * scale) / 2
        let translationY: CGFloat = (drawableSize.height - image.extent.height * scale) / 2
        let scaledImage = image
            .transformed(by: CGAffineTransform(translationX: translationX, y: translationY))
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        context.render(scaledImage, to: drawable.texture, commandBuffer: commandBuffer, bounds: bounds, colorSpace: colorSpace)
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

extension MTKLFView: NetStreamDrawable {
    // MARK: NetStreamDrawable
    func draw(image: CIImage) {
        DispatchQueue.main.async {
            self.displayImage = image
            self.needsDisplay = true
        }
    }
}
