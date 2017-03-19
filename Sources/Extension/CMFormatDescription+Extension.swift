import Foundation
import CoreMedia

extension CMFormatDescription {
    var extensions:[String: AnyObject]? {
        return CMFormatDescriptionGetExtensions(self) as? [String : AnyObject]
    }

    func getExtension(by key:String) -> [String: AnyObject]? {
        return CMFormatDescriptionGetExtension(self, key as CFString) as? [String : AnyObject]
    }
}
