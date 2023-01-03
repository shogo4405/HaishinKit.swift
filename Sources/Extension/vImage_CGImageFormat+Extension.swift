import Accelerate
import Foundation

extension vImage_CGImageFormat {
    @available(iOS, obsoleted: 13.0)
    @available(tvOS, obsoleted: 13.0)
    @available(macOS, obsoleted: 10.15)
    init?(cgImage: CGImage) {
        guard
            let colorSpace = cgImage.colorSpace else {
            return nil
        }
        self = vImage_CGImageFormat(
            bitsPerComponent: UInt32(cgImage.bitsPerComponent),
            bitsPerPixel: UInt32(cgImage.bitsPerPixel),
            colorSpace: Unmanaged.passRetained(colorSpace),
            bitmapInfo: cgImage.bitmapInfo,
            version: 0,
            decode: nil,
            renderingIntent: cgImage.renderingIntent)
    }
}
