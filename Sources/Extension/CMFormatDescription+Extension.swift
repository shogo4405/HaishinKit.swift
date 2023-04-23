import CoreMedia
import Foundation

extension CMFormatDescription {
    var _mediaType: CMMediaType {
        CMFormatDescriptionGetMediaType(self)
    }

    func `extension`(by key: String) -> [String: AnyObject]? {
        CMFormatDescriptionGetExtension(self, extensionKey: key as CFString) as? [String: AnyObject]
    }
}
