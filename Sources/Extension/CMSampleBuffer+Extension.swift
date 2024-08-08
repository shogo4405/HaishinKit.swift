import Accelerate
import AVFoundation
import CoreMedia

extension CMSampleBuffer {
    static let ScreenObjectImageTarget: CFString = "ScreenObjectImageTarget" as CFString

    @inlinable @inline(__always) var isNotSync: Bool {
        get {
            guard !sampleAttachments.isEmpty else {
                return false
            }
            return sampleAttachments[0][.notSync] != nil
        }
        set {
            guard !sampleAttachments.isEmpty else {
                return
            }
            sampleAttachments[0][.notSync] = newValue ? 1 : nil
        }
    }

    var targetType: ScreenObject.ImageTarget? {
        get {
            guard let rawTargetAttachment = CMGetAttachment(
                self,
                key: CMSampleBuffer.ScreenObjectImageTarget as CFString,
                attachmentModeOut: nil) as? NSNumber
            else { return nil }

            return ScreenObject.ImageTarget(rawValue: rawTargetAttachment.intValue)
        }
        set {
            if let value = newValue {
                CMSetAttachment(self,
                                key: CMSampleBuffer.ScreenObjectImageTarget,
                                value: NSNumber(value: value.rawValue),
                                attachmentMode: kCMAttachmentMode_ShouldPropagate)
            } else {
                CMRemoveAttachment(self, key: CMSampleBuffer.ScreenObjectImageTarget)
            }
        }
    }
}
