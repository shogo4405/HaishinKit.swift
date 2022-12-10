import Accelerate
import CoreMedia
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
    mutating func cornerRadius(_ radius: CGFloat) -> Self {
        guard 0 < radius else {
            return self
        }
        let buffer = data.assumingMemoryBound(to: Pixel_8.self)
        for x in 0 ..< Int(width) {
            for y in 0 ..< Int(height) {
                let index = y * rowBytes + x * 4
                var dx = CGFloat(min(x, Int(width) - x))
                var dy = CGFloat(min(y, Int(height) - y))
                if dx == 0 && dy == 0 {
                    buffer[index] = 0
                    continue
                }
                if radius < dx || radius < dy {
                    continue
                }
                dx = radius - dx
                dy = radius - dy
                if radius < round(sqrt(dx * dx + dy * dy)) {
                    buffer[index] = 0
                }
            }
        }
        return self
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

    @available(iOS, obsoleted: 13.0)
    @available(tvOS, obsoleted: 13.0)
    @available(macOS, obsoleted: 10.15)
    func free() {
        Darwin.free(data)
    }
}
