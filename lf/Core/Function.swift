import Foundation

func IsNoErr(status:OSStatus) -> Bool {
    if (status == noErr) {
        return true
    }
    logger.warning("\(status)")
    return false
}

func IsNoErr(status:OSStatus, _ message:String) -> Bool {
    if (status == noErr) {
        return true
    }
    logger.warning("\(message)(\(status))")
    return false
}

func IsNoErr(status:OSStatus, _ lambda:() -> Void) -> Bool {
    if (status == noErr) {
        return true
    }
    logger.warning("\(status)")
    lambda()
    return false
}

func IsNoErr(status:OSStatus, _ message:String, _ lambda:() -> Void) -> Bool {
    if (status == noErr) {
        return true
    }
    logger.warning("\(message)(\(status))")
    lambda()
    return false
}
