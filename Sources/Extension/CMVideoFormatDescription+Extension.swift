import CoreImage
import CoreMedia

extension CMVideoFormatDescription {
    @available(iOS, obsoleted: 13.0)
    @available(tvOS, obsoleted: 13.0)
    @available(macOS, obsoleted: 10.15)
    var dimensions: CMVideoDimensions {
        CMVideoFormatDescriptionGetDimensions(self)
    }
}
