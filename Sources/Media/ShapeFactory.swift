import Accelerate
import CoreMedia
import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

class ShapeFactory {
    static let shared = ShapeFactory()

    private var imageBuffers: [String: vImage_Buffer] = [:]

    func cornerRadius(_ size: CGSize, cornerRadius: CGFloat) -> vImage_Buffer {
        let key = "\(size.width):\(size.height):\(cornerRadius)"
        if let buffer = imageBuffers[key] {
            return buffer
        }
        var imageBuffer = vImage_Buffer()
        guard
            let image = makeCGImage(.init(origin: .zero, size: size), cornerRadius: cornerRadius),
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

    #if canImport(UIKit)
    private func makeCGImage(_ rect: CGRect, cornerRadius: CGFloat) -> CGImage? {
        UIGraphicsBeginImageContext(rect.size)
        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }
        let roundedPath = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
        context.setFillColor(UIColor.white.cgColor)
        context.addPath(roundedPath.cgPath)
        context.closePath()
        context.fillPath()
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image?.cgImage
    }
    #endif

    #if canImport(AppKit)
    private func makeCGImage(_ rect: CGRect, cornerRadius: CGFloat) -> CGImage? {
        guard let context = CGContext(
            data: nil,
            width: Int(rect.width),
            height: Int(rect.height),
            bitsPerComponent: 8,
            bytesPerRow: Int(rect.width) * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue).rawValue
        ) else {
            return nil
        }
        let path = CGPath.init(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        context.setFillColor(NSColor.white.cgColor)
        context.addPath(path)
        context.closePath()
        context.fillPath()
        return context.makeImage()
    }
    #endif
}
