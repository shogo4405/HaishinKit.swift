import Accelerate
import CoreMedia
import Foundation

extension vImage_Buffer {
    enum TransformDirection {
        case north
        case south
        case east
        case west

        var opposite: TransformDirection {
            switch self {
            case .north:
                return .south
            case .south:
                return .north
            case .east:
                return .west
            case .west:
                return .east
            }
        }

        func tx(_ width: Double) -> Double {
            switch self {
            case .north:
                return 0.0
            case .south:
                return Double.leastNonzeroMagnitude
            case .east:
                return width / 2
            case .west:
                return -(width / 2)
            }
        }

        func ty(_ height: Double) -> Double {
            switch self {
            case .north:
                return height / 2
            case .south:
                return -(height / 2)
            case .east:
                return Double.leastNonzeroMagnitude
            case .west:
                return 0.0
            }
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
    mutating func split(_ buffer: inout vImage_Buffer, direction: TransformDirection) -> Self {
        buffer.transform(direction.opposite)
        transform(direction)
        guard vImageAlphaBlend_ARGB8888(
            &self,
            &buffer,
            &self,
            vImage_Flags(kvImageDoNotTile)
        ) == kvImageNoError else {
            return self
        }
        return self
    }

    private mutating func transform(_ direction: TransformDirection) {
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
