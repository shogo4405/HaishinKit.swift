import XCGLogger

let logger:XCGLogger = XCGLogger.defaultInstance()

#if os(OSX)
// TODO
let kCVPixelBufferOpenGLESCompatibilityKey:String = ""
let kAppleSoftwareAudioCodecManufacturer:OSType = 0
let kAppleHardwareAudioCodecManufacturer:OSType = 0
#endif
