import Foundation

func IsNoErr(status:OSStatus, _ message:String) -> Bool {
    if (status == noErr) {
        return true
    }
    logger.warning(message)
    return false
}

func IsNoErr(status:OSStatus, _ lambda:() -> Void) -> Bool {
    if (status == noErr) {
        return true
    }
    lambda()
    return false
}

func IsNoErr(status:OSStatus, _ message:String, _ lambda:() -> Void) -> Bool {
    if (status == noErr) {
        return true
    }
    logger.warning(message)
    lambda()
    return false
}
