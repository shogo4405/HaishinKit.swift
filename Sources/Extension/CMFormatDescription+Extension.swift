import CoreMedia
import Foundation

extension CMFormatDescription {
    func `extension`(by key: String) -> [String: AnyObject]? {
        return CMFormatDescriptionGetExtension(self, extensionKey: key as CFString) as? [String: AnyObject]
    }
}
