import CoreVideo
import Foundation

extension CVPixelBuffer {
    var width: Int {
        CVPixelBufferGetWidth(self)
    }

    var height: Int {
        CVPixelBufferGetHeight(self)
    }

    @discardableResult
    func lockBaseAddress(_ lockFlags: CVPixelBufferLockFlags = []) -> CVReturn {
        return CVPixelBufferLockBaseAddress(self, lockFlags)
    }

    @discardableResult
    func unlockBaseAddress(_ lockFlags: CVPixelBufferLockFlags = []) -> CVReturn {
        return CVPixelBufferUnlockBaseAddress(self, lockFlags)
    }
}
