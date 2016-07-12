import Foundation
import AVFoundation

// MARK: ScreenCaptureOutputPixelBufferDelegate
public protocol ScreenCaptureOutputPixelBufferDelegate: class {
    func didSetSize(size:CGSize)
    func pixelBufferOutput(pixelBuffer:CVPixelBufferRef, timestamp:CMTime)
}
