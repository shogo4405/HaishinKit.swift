import CoreMedia
import Foundation

extension CMFormatDescription {
    @available(iOS, obsoleted: 13.0)
    @available(tvOS, obsoleted: 13.0)
    @available(macOS, obsoleted: 10.15)
    var mediaType: CMMediaType {
        CMFormatDescriptionGetMediaType(self)
    }

    func `extension`(by key: String) -> [String: AnyObject]? {
        CMFormatDescriptionGetExtension(self, extensionKey: key as CFString) as? [String: AnyObject]
    }
}
