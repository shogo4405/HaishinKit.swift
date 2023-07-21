import CoreMedia
import Foundation

extension CMFormatDescription {
    var _mediaType: CMMediaType {
        CMFormatDescriptionGetMediaType(self)
    }

    @available(iOS, obsoleted: 13.0)
    @available(tvOS, obsoleted: 13.0)
    @available(macOS, obsoleted: 10.15)
    var audioStreamBasicDescription: AudioStreamBasicDescription? {
        return CMAudioFormatDescriptionGetStreamBasicDescription(self)?.pointee
    }
}
