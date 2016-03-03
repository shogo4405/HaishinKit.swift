import Foundation
import AudioToolbox

public struct SoundTransform {

    static public let defaultValue:Float32 = 1.0
    static public let defaultPlayRate:Float32 = 1.0
    static public let defaultPitch:Float32 = 1200
    static public let defaultVolumeRampTime:Float32 = 0
    static public let defaultPan:Float32 = 0

    public var volume:Float32 = SoundTransform.defaultValue
    public var playRate:Float32 = SoundTransform.defaultPlayRate
    public var pitch:Float32 = SoundTransform.defaultPitch
    public var volumeRampTime:Float32 = SoundTransform.defaultVolumeRampTime
    public var pan:Float32 = SoundTransform.defaultPan

    func setParameter(inAQ: AudioQueueRef) {
        if (AudioQueueSetParameter(inAQ, kAudioQueueParam_Volume, volume) != noErr) {
            logger.warning("set volume = \(volume)")
        }
        if (AudioQueueSetParameter(inAQ, kAudioQueueParam_PlayRate, playRate) != noErr) {
            logger.warning("set playrate = \(playRate)")
        }
        if (AudioQueueSetParameter(inAQ, kAudioQueueParam_Pitch, pitch) != noErr) {
            logger.warning("set pitch = \(pitch)")
        }
        if (AudioQueueSetParameter(inAQ, kAudioQueueParam_VolumeRampTime, volumeRampTime) != noErr) {
            logger.warning("set volueRampTime = \(volumeRampTime)")
        }
        if (AudioQueueSetParameter(inAQ, kAudioQueueParam_Pan, pan) != noErr) {
            logger.warning("set pan = \(pan)")
        }
    }
}
