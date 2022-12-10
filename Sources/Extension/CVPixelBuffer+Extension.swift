import Accelerate
import CoreVideo
import Foundation

extension CVPixelBuffer {
    enum Error: Swift.Error {
        case failedToMakevImage_Buffer(_ error: vImage_Error)
    }

    static var format = vImage_CGImageFormat(
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        colorSpace: nil,
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.first.rawValue),
        version: 0,
        decode: nil,
        renderingIntent: .defaultIntent)

    var width: Int {
        CVPixelBufferGetWidth(self)
    }

    var height: Int {
        CVPixelBufferGetHeight(self)
    }

    @discardableResult
    func over(_ pixelBuffer: CVPixelBuffer?, regionOfInterest roi: CGRect = .zero, radius: CGFloat = 0.0) -> Self {
        guard var inputImageBuffer = try? pixelBuffer?.makevImage_Buffer(format: &Self.format) else {
            return self
        }
        defer {
            inputImageBuffer.free()
        }
        guard var srcImageBuffer = try? makevImage_Buffer(format: &Self.format) else {
            return self
        }
        defer {
            srcImageBuffer.free()
        }
        let xScale = Float(roi.width) / Float(inputImageBuffer.width)
        let yScale = Float(roi.height) / Float(inputImageBuffer.height)
        let scaleFactor = (xScale < yScale) ? xScale : yScale
        var scaledInputImageBuffer = inputImageBuffer.scale(scaleFactor)
        scaledInputImageBuffer.cornerRadius(radius)
        defer {
            scaledInputImageBuffer.free()
        }
        srcImageBuffer.over(&scaledInputImageBuffer, origin: roi.origin)
        srcImageBuffer.copy(to: self, format: &Self.format)
        return self
    }

    func makevImage_Buffer(format: inout vImage_CGImageFormat) throws -> vImage_Buffer {
        var buffer = vImage_Buffer()
        let cvImageFormat = vImageCVImageFormat_CreateWithCVPixelBuffer(self).takeRetainedValue()
        vImageCVImageFormat_SetColorSpace(cvImageFormat, CGColorSpaceCreateDeviceRGB())
        let error = vImageBuffer_InitWithCVPixelBuffer(
            &buffer,
            &format,
            self,
            cvImageFormat,
            nil,
            vImage_Flags(kvImageNoFlags))
        if error != kvImageNoError {
            throw Error.failedToMakevImage_Buffer(error)
        }
        return buffer
    }

    @discardableResult
    func lockBaseAddress(_ lockFlags: CVPixelBufferLockFlags = CVPixelBufferLockFlags.readOnly) -> CVReturn {
        return CVPixelBufferLockBaseAddress(self, lockFlags)
    }

    @discardableResult
    func unlockBaseAddress(_ lockFlags: CVPixelBufferLockFlags = CVPixelBufferLockFlags.readOnly) -> CVReturn {
        return CVPixelBufferUnlockBaseAddress(self, lockFlags)
    }
}
