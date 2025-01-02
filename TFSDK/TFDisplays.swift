#if os(iOS) || os(tvOS) || os(macOS)

import AVFoundation
import MetalKit
import HaishinKit
/// A view that displays a video content of a NetStream object which uses Metal api.
public class TFDisplays: MTKView {
    //前摄像 or 后摄像头
    var position = AVCaptureDevice.Position.front
    // 添加镜像显示控制属性
    public var isMirrorDisplay: Bool = false
    /// Specifies how the video is displayed within a player layer’s bounds.
    public var videoGravity: AVLayerVideoGravity = .resizeAspect
    public var videoTrackId: UInt8? = UInt8.max
    public var audioTrackId: UInt8?
    private var displayImage: CIImage?
    private lazy var commandQueue: (any MTLCommandQueue)? = {
        return device?.makeCommandQueue()
    }()
    private var context: CIContext?
    private var effects: [any VideoEffect] = .init()

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
    override public func awakeFromNib() {
        super.awakeFromNib()
        Task { @MainActor in
            framebufferOnly = false
            enableSetNeedsDisplay = true
            if let device {
                context = CIContext(mtlDevice: device, options: [.cacheIntermediates: false, .name: "TFDisplays"])
            }
        }
    }
    private let imageProcessor = ImageProcessor()
    /// Redraws the view’s contents.
    override public func draw(_ rect: CGRect) {
        
        if let displayImage2 = displayImage , isMirrorDisplay  {
             //前置
            if position == .front {
                // 使用优化后的方法
                if let mirrored = imageProcessor.mirrorImage(displayImage2) {
                    displayImage = mirrored
                }
            }
          
                   
            
          }
        
        
        guard
            let context,
            let currentDrawable = currentDrawable,
            let commandBuffer = commandQueue?.makeCommandBuffer() else {
            return
        }
        if
            let currentRenderPassDescriptor = currentRenderPassDescriptor,
            let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: currentRenderPassDescriptor) {
            renderCommandEncoder.endEncoding()
        }
        guard let displayImage else {
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

        var scaledImage: CIImage = displayImage
        for effect in effects {
            scaledImage = effect.execute(scaledImage)
        }

        scaledImage = scaledImage
            .transformed(by: CGAffineTransform(translationX: translationX, y: translationY))
            .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        let destination = CIRenderDestination(
            width: Int(drawableSize.width),
            height: Int(drawableSize.height),
            pixelFormat: colorPixelFormat,
            commandBuffer: commandBuffer,
            mtlTextureProvider: { () -> (any MTLTexture) in
                return currentDrawable.texture
            })

        _ = try? context.startTask(toRender: scaledImage, to: destination)

        commandBuffer.present(currentDrawable)
        commandBuffer.commit()
    }

    /// Registers a video effect.
    public func registerVideoEffect(_ effect: some VideoEffect) -> Bool {
        if effects.contains(where: { $0 === effect }) {
            return false
        }
        effects.append(effect)
        return true
    }

    /// Unregisters a video effect.
    public func unregisterVideoEffect(_ effect: some VideoEffect) -> Bool {
        if let index = effects.firstIndex(where: { $0 === effect }) {
            effects.remove(at: index)
            return true
        }
        return false
    }
}

extension TFDisplays: MediaMixerOutput {
    // MARK: MediaMixerOutput
    public func selectTrack(_ id: UInt8?, mediaType: CMFormatDescription.MediaType) async {
        switch mediaType {
        case .audio:
            break
        case .video:
            videoTrackId = id
        default:
            break
        }
    }

    nonisolated public func mixer(_ mixer: MediaMixer, didOutput buffer: AVAudioPCMBuffer, when: AVAudioTime) {
    }

    nonisolated public func mixer(_ mixer: MediaMixer, didOutput sampleBuffer: CMSampleBuffer) {
        Task { @MainActor in
            displayImage = try? sampleBuffer.imageBuffer?.makeCIImage()
            #if os(macOS)
            self.needsDisplay = true
            #else
            self.setNeedsDisplay()
            #endif
        }
    }
}

extension TFDisplays: HKStreamOutput {
    // MARK: HKStreamOutput
    nonisolated public func stream(_ stream: some HKStream, didOutput audio: AVAudioBuffer, when: AVAudioTime) {
    }

    nonisolated public func stream(_ stream: some HKStream, didOutput video: CMSampleBuffer) {
        Task { @MainActor in
            displayImage = try? video.imageBuffer?.makeCIImage()
            #if os(macOS)
            self.needsDisplay = true
            #else
            self.setNeedsDisplay()
            #endif
        }
    }
}

class ImageProcessor {
    // 保存复用的对象
    private let context: CIContext
    
    init() {
        // CIContext 创建成本较高，应该复用
        context = CIContext(options: [
            .useSoftwareRenderer: false,  // 使用GPU渲染
        ])
    }
    
    func mirrorImage(_ inputImage: CIImage) -> CIImage? {
        // 获取图像边界
        let bounds = inputImage.extent
        
        // 创建变换矩阵（可以考虑缓存这个transform如果都是相同尺寸图片）
        let transform = CGAffineTransform(translationX: bounds.width, y: 0).scaledBy(x: -1, y: 1)
        
        // 直接对 CIImage 进行变换，避免 CGImage 转换
        return inputImage.transformed(by: transform)
    }
    
    // 如果必须使用 CGImage 路径的版本
    func mirrorImageWithCG(_ inputImage: CIImage) -> CIImage? {
        let bounds = inputImage.extent
        
        guard let cgImage = context.createCGImage(inputImage, from: bounds) else {
            return nil
        }
        
        let transform = CGAffineTransform(translationX: bounds.width, y: 0).scaledBy(x: -1, y: 1)
        return CIImage(cgImage: cgImage).transformed(by: transform)
    }
}

#endif
