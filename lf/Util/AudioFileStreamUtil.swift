import Foundation
import AudioToolbox

final class AudioFileStreamUtil {
    private init() {
    }

    static func getFormatDescription(inAudioFileStream: AudioFileStreamID) -> AudioStreamBasicDescription? {
        var data:AudioStreamBasicDescription = AudioStreamBasicDescription()
        var size:UInt32 = UInt32(sizeof(data.dynamicType))
        guard AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_DataFormat, &size, &data) == noErr else {
            logger.warning("kAudioFileStreamProperty_DataFormat")
            return nil
        }
        return data
    }

    static func getMagicCookie(inAudioFileStream: AudioFileStreamID) -> [UInt8]? {
        var size:UInt32 = 0
        var writable:DarwinBoolean = true
        guard AudioFileStreamGetPropertyInfo(inAudioFileStream, kAudioFileStreamProperty_MagicCookieData, &size, &writable) == noErr else {
            logger.warning("info kAudioFileStreamProperty_MagicCookieData")
            return nil
        }
        var data:[UInt8] = [UInt8](count: Int(size), repeatedValue: 0)
        guard AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_MagicCookieData, &size, &data) == noErr else {
            logger.warning("kAudioFileStreamProperty_MagicCookieData")
            return nil
        }
        return data
    }
}