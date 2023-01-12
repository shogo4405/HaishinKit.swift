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
        var shape = ShapeFactory.shared.cornerRadius(CGSize(width: CGFloat(scaledInputImageBuffer.width), height: CGFloat(scaledInputImageBuffer.height)), cornerRadius: radius)
        vImageSelectChannels_ARGB8888(&shape, &scaledInputImageBuffer, &scaledInputImageBuffer, 0x8, vImage_Flags(kvImageNoFlags))
        defer {
            scaledInputImageBuffer.free()
        }
        srcImageBuffer.over(&scaledInputImageBuffer, origin: roi.origin)
        srcImageBuffer.copy(to: self, format: &Self.format)
        return self
    }

    @discardableResult
    func split(_ pixelBuffer: CVPixelBuffer?, direction: ImageTransform) -> Self {
        guard var inputImageBuffer = try? pixelBuffer?.makevImage_Buffer(format: &Self.format) else {
            return self
        }
        defer {
            inputImageBuffer.free()
        }
        guard var sourceImageBuffer = try? makevImage_Buffer(format: &Self.format) else {
            return self
        }
        defer {
            sourceImageBuffer.free()
        }
        let scaleX = Float(width) / Float(inputImageBuffer.width)
        let scaleY = Float(height) / Float(inputImageBuffer.height)
        var scaledInputImageBuffer = inputImageBuffer.scale(min(scaleY, scaleX))
        defer {
            scaledInputImageBuffer.free()
        }
        sourceImageBuffer.split(&scaledInputImageBuffer, direction: direction)
        sourceImageBuffer.copy(to: self, format: &Self.format)
        return self
    }

    @discardableResult
    func reflectHorizontal() -> Self {
        guard var imageBuffer = try? makevImage_Buffer(format: &Self.format) else {
            return self
        }
        defer {
            imageBuffer.free()
        }
        guard
            vImageHorizontalReflect_ARGB8888(
                &imageBuffer,
                &imageBuffer,
                vImage_Flags(kvImageLeaveAlphaUnchanged)) == kvImageNoError else {
            return self
        }
        imageBuffer.copy(to: self, format: &Self.format)
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
