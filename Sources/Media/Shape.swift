import Foundation

#if os(macOS)
import AppKit

class RoundedSquareShape: Shape {
    var rect: CGRect = .zero
    var cornerRadius: CGFloat = .zero

    func makeCGImage() -> CGImage? {
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
}

#else
import UIKit

class RoundedSquareShape: Shape {
    var rect: CGRect = .zero
    var cornerRadius: CGFloat = .zero

    func makeCGImage() -> CGImage? {
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
}

#endif
