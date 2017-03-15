import CoreMedia
import CoreImage

extension CMVideoFormatDescription {
    var dimensions:CMVideoDimensions {
        return CMVideoFormatDescriptionGetDimensions(self)
    }

    static func create(withPixelBuffer:CVPixelBuffer) -> CMVideoFormatDescription? {
        var formatDescription:CMFormatDescription?
        let status:OSStatus = CMVideoFormatDescriptionCreate(
            kCFAllocatorDefault,
            kCMVideoCodecType_422YpCbCr8,
            Int32(withPixelBuffer.width),
            Int32(withPixelBuffer.height),
            nil,
            &formatDescription
        )
        guard status == noErr else {
            logger.warning("\(status)")
            return nil
        }
        return formatDescription
    }
}
