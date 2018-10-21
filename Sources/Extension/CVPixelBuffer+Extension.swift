import Foundation

extension CVPixelBuffer {
    var width: Int {
        return CVPixelBufferGetWidth(self)
    }
    var height: Int {
        return CVPixelBufferGetHeight(self)
    }
}
