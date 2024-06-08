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
}
