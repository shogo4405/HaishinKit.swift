import Accelerate
import CoreMedia
import Foundation

extension vImage_Buffer {
    init?(cvPixelBuffer: CVPixelBuffer?, format: inout vImage_CGImageFormat) {
        guard let cvPixelBuffer else {
            return nil
        }
        self.init()
        let cvImageFormat = vImageCVImageFormat_CreateWithCVPixelBuffer(cvPixelBuffer).takeRetainedValue()
        vImageCVImageFormat_SetColorSpace(cvImageFormat, CGColorSpaceCreateDeviceRGB())
        guard vImageBuffer_InitWithCVPixelBuffer(
                &self,
                &format,
                cvPixelBuffer,
                cvImageFormat,
                nil,
                vImage_Flags(kvImageNoFlags)) == kvImageNoError else {
            return nil
        }
    }

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

    mutating func copy(to cvPixelBuffer: CVPixelBuffer, format: inout vImage_CGImageFormat) -> vImage_Error {
        let cvImageFormat = vImageCVImageFormat_CreateWithCVPixelBuffer(cvPixelBuffer).takeRetainedValue()
        vImageCVImageFormat_SetColorSpace(cvImageFormat, CGColorSpaceCreateDeviceRGB())
        return vImageBuffer_CopyToCVPixelBuffer(
            &self,
            &format,
            cvPixelBuffer,
            cvImageFormat,
            nil,
            vImage_Flags(kvImageNoFlags))
    }

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

    @available(iOS, obsoleted: 13.0)
    @available(tvOS, obsoleted: 13.0)
    @available(macOS, obsoleted: 10.15)
    func free() {
        Darwin.free(data)
    }
}
