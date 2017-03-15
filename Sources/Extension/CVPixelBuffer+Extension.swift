import Foundation

extension CVPixelBuffer {
    static func create(_ image:CIImage) -> CVPixelBuffer? {
        var buffer:CVPixelBuffer?
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(image.extent.width),
            Int(image.extent.height),
            kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            nil,
            &buffer
        )
        return buffer
    }
    var width:Int {
        return CVPixelBufferGetWidth(self)
    }
    var height:Int {
        return CVPixelBufferGetHeight(self)
    }
}
