import Accelerate
import CoreMedia
import Foundation

protocol Shape {
    func makeCGImage() -> CGImage?
}

class ShapeFactory {
    static let shared = ShapeFactory()

    private var imageBuffers: [String: vImage_Buffer] = [:]
    private var roundedSquareShape = RoundedSquareShape()
    private var halfRectShape = HalfRectShape()

    func cornerRadius(_ size: CGSize, cornerRadius: CGFloat) -> vImage_Buffer {
        let key = "\(size.width):\(size.height):\(cornerRadius)"
        if let buffer = imageBuffers[key] {
            return buffer
        }
        var imageBuffer = vImage_Buffer()
        roundedSquareShape.rect = .init(origin: .zero, size: size)
        roundedSquareShape.cornerRadius = cornerRadius
        guard
            let image = roundedSquareShape.makeCGImage(),
            var format = vImage_CGImageFormat(cgImage: image),
            vImageBuffer_InitWithCGImage(&imageBuffer, &format, nil, image, vImage_Flags(kvImageNoFlags)) == kvImageNoError else {
            return imageBuffer
        }
        imageBuffers[key] = imageBuffer
        return imageBuffer
    }

    func split(_ size: CGSize, direction: ImageTransform) -> vImage_Buffer {
        let key = "\(size.width):\(size.height):\(direction)"
        if let buffer = imageBuffers[key] {
            return buffer
        }
        var imageBuffer = vImage_Buffer()
        halfRectShape.rect = .init(origin: .zero, size: size)
        halfRectShape.direction = direction
        guard
            let image = halfRectShape.makeCGImage(),
            var format = vImage_CGImageFormat(cgImage: image),
            vImageBuffer_InitWithCGImage(&imageBuffer, &format, nil, image, vImage_Flags(kvImageNoFlags)) == kvImageNoError else {
            return imageBuffer
        }
        imageBuffers[key] = imageBuffer
        return imageBuffer
    }

    func removeAll() {
        for buffer in imageBuffers.values {
            buffer.free()
        }
        imageBuffers.removeAll()
    }
}
