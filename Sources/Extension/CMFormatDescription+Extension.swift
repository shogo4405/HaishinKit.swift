import CoreMedia
import Foundation

extension CMFormatDescription {
    var extensions: [String: AnyObject]? {
        return CMFormatDescriptionGetExtensions(self) as? [String: AnyObject]
    }

    func `extension`(by key: String) -> [String: AnyObject]? {
        return CMFormatDescriptionGetExtension(self, extensionKey: key as CFString) as? [String: AnyObject]
    }
}
