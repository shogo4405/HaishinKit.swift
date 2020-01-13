import CoreImage
import CoreMedia

extension CMVideoFormatDescription {
    @available(iOS, obsoleted: 13.0)
    @available(tvOS, obsoleted: 13.0)
    @available(macOS, obsoleted: 10.15)
    var dimensions: CMVideoDimensions {
        CMVideoFormatDescriptionGetDimensions(self)
    }

    static func create(pixelBuffer: CVPixelBuffer) -> CMVideoFormatDescription? {
        var formatDescription: CMFormatDescription?
        let status: OSStatus = CMVideoFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            codecType: kCMVideoCodecType_422YpCbCr8,
            width: Int32(pixelBuffer.width),
            height: Int32(pixelBuffer.height),
            extensions: nil,
            formatDescriptionOut: &formatDescription
        )
        guard status == noErr else {
            logger.warn("\(status)")
            return nil
        }
        return formatDescription
    }
}
