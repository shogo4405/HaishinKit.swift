import CoreMedia
import Foundation

extension CMFormatDescription {
    var _mediaType: CMMediaType {
        CMFormatDescriptionGetMediaType(self)
    }

    var _mediaSubType: FourCharCode {
        CMFormatDescriptionGetMediaSubType(self)
    }
}
