import Accelerate
import AVFoundation
import CoreMedia

extension CMSampleBuffer {
    @inlinable @inline(__always) var isNotSync: Bool {
        get {
            guard sampleAttachments.isEmpty else {
                return false
            }
            return sampleAttachments[0][.notSync] != nil
        }
        set {
            guard sampleAttachments.isEmpty else {
                return
            }
            sampleAttachments[0][.notSync] = newValue ? 1 : nil
        }
    }
}
