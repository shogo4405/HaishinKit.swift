import Foundation
import AudioToolbox

final class AudioQueueUtil {
    private init() {
    }

    static func addIsRuuningListener(inAQ: AudioQueueRef, _ inProc: AudioQueuePropertyListenerProc, _ inUserData: UnsafeMutablePointer<Void>) -> Bool {
        return addPropertyListener(inAQ, kAudioQueueProperty_IsRunning, inProc, inUserData)
    }

    static func isRunnning(inAQ: AudioQueueRef) -> Bool {
        var data:UInt32 = 0
        var size:UInt32 = UInt32(sizeof(data.dynamicType))
        var status:OSStatus = noErr
        status = AudioQueueGetProperty(inAQ, kAudioQueueProperty_IsRunning, &data, &size)
        if (status != noErr) {
            logger.warning("status \(status)")
            return data == 1
        }
        return data == 1
    }

    static func setMagicCookie(inAQ: AudioQueueRef, _ inData: [UInt8]) -> Bool {
        var status:OSStatus = noErr
        status = AudioQueueSetProperty(inAQ, kAudioQueueProperty_MagicCookie, inData, UInt32(inData.count))
        if (status != noErr) {
            logger.warning("status \(status)")
            return false
        }
        return true
    }

    static private func addPropertyListener(inAQ:AudioQueueRef, _ inID:AudioQueuePropertyID, _ inProc: AudioQueuePropertyListenerProc, _ inUserData: UnsafeMutablePointer<Void>) -> Bool {
        var status:OSStatus = noErr
        status = AudioQueueAddPropertyListener(inAQ, inID, inProc, inUserData)
        if (status != noErr) {
            logger.warning("status \(status)")
            return false
        }
        return true
    }
}

