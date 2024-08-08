import Accelerate
import AVFoundation
import CoreImage
import Foundation

/// A type that renders a screen object.
public protocol ScreenRenderer: AnyObject {
    /// The CIContext instance.
    var context: CIContext { get }
    /// Specifies the backgroundColor for output video.
    var backgroundColor: CGColor { get set }
    /// The current screen bounds.
    var bounds: CGRect { get }
    /// Layouts a screen object.
    func layout(_ screenObject: ScreenObject)
    /// Draws a sceen object.
    func draw(_ screenObject: ScreenObject)
    /// Sets up the render target.
    func setTarget(_ pixelBuffer: CVPixelBuffer?, _ targetType: ScreenObject.ImageTarget)
}

final class ScreenRendererByCPU: ScreenRenderer {
    static let noFlags = vImage_Flags(kvImageNoFlags)

    var bounds: CGRect = .init(origin: .zero, size: Screen.size)

    lazy var context = {
        guard let deive = MTLCreateSystemDefaultDevice() else {
            return CIContext(options: nil)
        }
        return CIContext(mtlDevice: deive)
    }()

    var backgroundColor = CGColor(red: 0x00, green: 0x00, blue: 0x00, alpha: 0x00) {
        didSet {
            guard backgroundColor != oldValue, let components = backgroundColor.components else {
                return
            }
            switch components.count {
            case 2:
                backgroundColorUInt8Array = [
                    UInt8(components[1] * 255),
                    UInt8(components[0] * 255),
                    UInt8(components[0] * 255),
                    UInt8(components[0] * 255)
                ]
            case 3:
                backgroundColorUInt8Array = [
                    UInt8(components[2] * 255),
                    UInt8(components[0] * 255),
                    UInt8(components[1] * 255),
                    UInt8(components[1] * 255)
                ]
            case 4:
                backgroundColorUInt8Array = [
                    UInt8(components[3] * 255),
                    UInt8(components[0] * 255),
                    UInt8(components[1] * 255),
                    UInt8(components[2] * 255)
                ]
            default:
                break
            }
        }
    }
    private var format = vImage_CGImageFormat(
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        colorSpace: nil,
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.first.rawValue),
        version: 0,
        decode: nil,
        renderingIntent: .defaultIntent)
    private var images: [ScreenObject: vImage_Buffer] = [:]
    private var viewImages: [ScreenObject: vImage_Buffer] = [:]
    private var canvas: vImage_Buffer = .init()
    private var viewCanvas: vImage_Buffer = .init()
    private var converter: vImageConverter?
    private var shapeFactory = ShapeFactory()
    private var pixelFormatType: OSType? {
        didSet {
            guard pixelFormatType != oldValue else {
                return
            }
            converter = nil
        }
    }
    private var backgroundColorUInt8Array: [UInt8] = [0x00, 0x00, 0x00, 0x00]
    private lazy var choromaKeyProcessor: ChromaKeyProcessor? = {
        return try? ChromaKeyProcessor()
    }()

    func setTarget(_ pixelBuffer: CVPixelBuffer?, _ targetType: ScreenObject.ImageTarget = .both) {
        guard let pixelBuffer else {
            return
        }
        switch targetType {
        case .view:
            setTarget(pixelBuffer, &viewCanvas)
        default:
            setTarget(pixelBuffer, &canvas)
        }
    }

    func layout(_ screenObject: ScreenObject) {
        autoreleasepool {
            let imageList = screenObject.makeImage(self)
            for (target, image) in imageList {
                guard let image else {
                    continue
                }
                switch target {
                case .view:
                    layout(screenObject, image, &viewImages)
                case .stream:
                    layout(screenObject, image, &images)
                case .both:
                    layout(screenObject, image, &images)
                    layout(screenObject, image, &viewImages)
                }
            }
        }
    }

    func draw(_ screenObject: ScreenObject) {
        let origin = screenObject.bounds.origin

        if var image = images[screenObject] {
            draw(&image, canvas, origin)
        }

        if var viewImage = viewImages[screenObject] {
            draw(&viewImage, viewCanvas, origin)
        }
    }

    func setTarget(_ pixelBuffer: CVPixelBuffer?, _ canvas: inout vImage_Buffer) {
        guard let pixelBuffer else {
            return
        }
        pixelFormatType = pixelBuffer.pixelFormatType
        if converter == nil {
            let cvImageFormat = vImageCVImageFormat_CreateWithCVPixelBuffer(pixelBuffer).takeRetainedValue()
            vImageCVImageFormat_SetColorSpace(cvImageFormat, CGColorSpaceCreateDeviceRGB())
            converter = try? vImageConverter.make(
                sourceFormat: cvImageFormat,
                destinationFormat: format
            )
        }
        guard let converter else {
            return
        }
        vImageBuffer_InitForCopyFromCVPixelBuffer(
            &canvas,
            converter,
            pixelBuffer,
            vImage_Flags(kvImageNoAllocate)
        )
        switch pixelFormatType {
        case kCVPixelFormatType_32ARGB:
            vImageBufferFill_ARGB8888(
                &canvas,
                &backgroundColorUInt8Array,
                vImage_Flags(kvImageNoFlags)
            )
        default:
            break
        }
    }

    private func layout(_ screenObject: ScreenObject, _ image: CGImage, _ images: inout [ScreenObject: vImage_Buffer]) {
        do {
            images[screenObject]?.free()
            var buffer = try vImage_Buffer(cgImage: image, format: format)
            images[screenObject] = buffer
            if 0 < screenObject.cornerRadius {
                if var mask = shapeFactory.cornerRadius(image.size, cornerRadius: screenObject.cornerRadius) {
                    vImageOverwriteChannels_ARGB8888(&mask, &buffer, &buffer, 0x8, Self.noFlags)
                }
            } else {
                if let screenObject = screenObject as? (any ChromaKeyProcessorble),
                   let chromaKeyColor = screenObject.chromaKeyColor,
                   var mask = try choromaKeyProcessor?.makeMask(&buffer, chromeKeyColor: chromaKeyColor) {
                    vImageOverwriteChannels_ARGB8888(&mask, &buffer, &buffer, 0x8, Self.noFlags)
                }
            }
        } catch {
            logger.error(error)
        }
    }

    private func draw(_ image: inout vImage_Buffer, _ canvas: vImage_Buffer, _ origin: CGPoint) {
        let start = Int(max(0, origin.y)) * canvas.rowBytes + Int(max(0, origin.x)) * 4

        var destination = vImage_Buffer(
            data: canvas.data.advanced(by: start),
            height: image.height,
            width: image.width,
            rowBytes: canvas.rowBytes
        )

        switch pixelFormatType {
        case kCVPixelFormatType_32ARGB:
            vImageAlphaBlend_ARGB8888(
                &image,
                &destination,
                &destination,
                vImage_Flags(kvImageDoNotTile)
            )
        default:
            break
        }
    }
}
