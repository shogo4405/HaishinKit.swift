import Foundation
import VideoToolbox

protocol VTSessionPropertyKey {
    var key: CFString { get }

    func setProperty(_ session: VTSession?, _ value: CFTypeRef?) -> OSStatus
    func getProperty(_ session: VTSession?) -> NSObject?
}

extension VTSessionPropertyKey {
    func getProperty(_ session: VTSession?) -> NSObject? {
        guard let session = session else {
            return nil
        }
        var data = NSObject()
        let value = UnsafeMutableRawPointer(&data)
        VTSessionCopyProperty(session, key: key, allocator: nil, valueOut: value)
        return data
    }

    func setProperty(_ session: VTSession?, _ value: CFTypeRef?) -> OSStatus {
        guard let session = session else {
            return kVTInvalidSessionErr
        }
        return VTSessionSetProperty(session, key: key, value: value)
    }
}
