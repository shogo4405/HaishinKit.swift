import Foundation

@inline(__always) func IsNoErr(status:OSStatus) -> Bool {
    if (status == noErr) {
        return true
    }
    logger.warning("\(status)")
    return false
}

@inline(__always) func IsNoErr(status:OSStatus, _ message:String) -> Bool {
    if (status == noErr) {
        return true
    }
    logger.warning("\(message)(\(status))")
    return false
}
