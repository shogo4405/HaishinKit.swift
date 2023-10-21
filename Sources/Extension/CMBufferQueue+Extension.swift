import CoreMedia
import Foundation

extension CMBufferQueue {
    @available(iOS, obsoleted: 13.0)
    @available(tvOS, obsoleted: 13.0)
    @available(macOS, obsoleted: 10.15)
    var duration: CMTime {
        CMBufferQueueGetDuration(self)
    }
}
