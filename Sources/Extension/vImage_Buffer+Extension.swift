import Accelerate
import CoreMedia
import CoreVideo
import Foundation

extension vImage_Buffer {
    init?(height: vImagePixelCount, width: vImagePixelCount, pixelBits: UInt32, flags: vImage_Flags) {
        self.init()
        guard vImageBuffer_Init(
                &self,
                height,
                width,
                pixelBits,
                flags) == kvImageNoError else {
            return nil
        }
    }

    @discardableResult
    mutating func copy(to cvPixelBuffer: CVPixelBuffer, format: inout vImage_CGImageFormat) -> vImage_Error {
        let cvImageFormat = vImageCVImageFormat_CreateWithCVPixelBuffer(cvPixelBuffer).takeRetainedValue()
        vImageCVImageFormat_SetColorSpace(cvImageFormat, CGColorSpaceCreateDeviceRGB())
        defer {
            if let dictionary = CVBufferGetAttachments(cvPixelBuffer, .shouldNotPropagate) {
                CVBufferSetAttachments(cvPixelBuffer, dictionary, .shouldPropagate)
            }
        }
        return vImageBuffer_CopyToCVPixelBuffer(
            &self,
            &format,
            cvPixelBuffer,
            cvImageFormat,
            nil,
            vImage_Flags(kvImageNoFlags))
    }

    @discardableResult
    mutating func scale(_ factor: Float) -> Self {
        var imageBuffer = vImage_Buffer()
        guard vImageBuffer_Init(
                &imageBuffer,
                vImagePixelCount(Float(height) * factor),
                vImagePixelCount(Float(width) * factor),
                32,
                vImage_Flags(kvImageNoFlags)) == kvImageNoError else {
            return self
        }
        guard vImageScale_ARGB8888(
                &self,
                &imageBuffer,
                nil,
                vImage_Flags(kvImageNoFlags)) == kvImageNoError else {
            return self
        }
        return imageBuffer
    }

    @discardableResult
    mutating func over(_ src: inout vImage_Buffer, origin: CGPoint = .zero) -> Self {
        let start = Int(origin.y) * rowBytes + Int(origin.x) * 4
        var destination = vImage_Buffer(
            data: data.advanced(by: start),
            height: vImagePixelCount(src.height),
            width: vImagePixelCount(src.width),
            rowBytes: rowBytes
        )
        guard vImageAlphaBlend_ARGB8888(
            &src,
            &destination,
            &destination,
            vImage_Flags(kvImageDoNotTile)
        ) == kvImageNoError else {
            return self
        }
        return self
    }

    @discardableResult
    mutating func split(_ buffer: inout vImage_Buffer, direction: ImageTransform) -> Self {
        buffer.transform(direction.opposite)
        var shape = ShapeFactory.shared.split(CGSize(width: CGFloat(width), height: CGFloat(height)), direction: direction.opposite)
        vImageSelectChannels_ARGB8888(&shape, &buffer, &buffer, 0x8, vImage_Flags(kvImageNoFlags))
        transform(direction)
        guard vImageAlphaBlend_ARGB8888(
            &buffer,
            &self,
            &self,
            vImage_Flags(kvImageDoNotTile)
        ) == kvImageNoError else {
            return self
        }
        return self
    }

    private mutating func transform(_ direction: ImageTransform) {
        let backgroundColor: [Pixel_8] = [0, 255, 255, 255]
        var vImageTransform = vImage_CGAffineTransform(
            a: 1,
            b: 0,
            c: 0,
            d: 1,
            tx: direction.tx(Double(width)),
            ty: direction.ty(Double(height))
        )
        vImageAffineWarpCG_ARGB8888(
            &self,
            &self,
            nil,
            &vImageTransform,
            backgroundColor,
            vImage_Flags(kvImageBackgroundColorFill)
        )
    }

    @available(iOS, obsoleted: 13.0)
    @available(tvOS, obsoleted: 13.0)
    @available(macOS, obsoleted: 10.15)
    func free() {
        Darwin.free(data)
    }
}
