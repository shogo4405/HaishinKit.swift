import Foundation
import AudioToolbox

final class AudioQueueUtil {
    private init() {
    }

    static func setMagicCookie(inAQ: AudioQueueRef, inData: [UInt8]) -> Bool {
        guard AudioQueueSetProperty(inAQ, kAudioQueueProperty_MagicCookie, inData, UInt32(inData.count)) == noErr else {
            logger.warning("kAudioQueueProperty_MagicCookie")
            return false
        }
        return true
    }
}

