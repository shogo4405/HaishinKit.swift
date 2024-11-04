import CoreVideo
import Foundation

extension CVPixelBufferPool {
    @discardableResult
    func createPixelBuffer(_ pixelBuffer: UnsafeMutablePointer<CVPixelBuffer?>) -> CVReturn {
        return CVPixelBufferPoolCreatePixelBuffer(
            kCFAllocatorDefault,
            self,
            pixelBuffer
        )
    }
}
