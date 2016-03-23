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

/**
 
 Increments the given value. This function is a workaround for deprecation of `++` operator in swift 2.2/3.0.
 
 - Parameter value: value to be incremented.
 
 */
func increment<T: ForwardIndexType>(inout value: T) -> T {
    
    value = value.successor()
    return value
    
}

/**
 
 Decrements the given value. This function is a workaround for deprecation of `--` operator in swift 2.2/3.0.
 
 - Parameter value: value to be decremented.
 
 */
func decrement<T: BidirectionalIndexType>(inout value: T) -> T {
    
    value = value.predecessor()
    return value
    
}
