import CoreMedia
import CoreImage

extension CMVideoFormatDescription {
    var dimensions: CMVideoDimensions {
        return CMVideoFormatDescriptionGetDimensions(self)
    }

    static func create(pixelBuffer: CVPixelBuffer) -> CMVideoFormatDescription? {
        var formatDescription: CMFormatDescription?
        let status: OSStatus = CMVideoFormatDescriptionCreate(
            kCFAllocatorDefault,
            kCMVideoCodecType_422YpCbCr8,
            Int32(pixelBuffer.width),
            Int32(pixelBuffer.height),
            nil,
            &formatDescription
        )
        guard status == noErr else {
            logger.warn("\(status)")
            return nil
        }
        return formatDescription
    }
}
