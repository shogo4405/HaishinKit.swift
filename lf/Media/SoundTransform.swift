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
        IsNoErr(AudioQueueSetParameter(inAQ, kAudioQueueParam_Volume, volume), "set volume = \(volume)")
        IsNoErr(AudioQueueSetParameter(inAQ, kAudioQueueParam_PlayRate, playRate), "set playrate = \(playRate)")
        IsNoErr(AudioQueueSetParameter(inAQ, kAudioQueueParam_Pitch, pitch), "set pitch = \(pitch)")
        IsNoErr(AudioQueueSetParameter(inAQ, kAudioQueueParam_VolumeRampTime, volumeRampTime), "set volumeRampTime = \(volumeRampTime)")
        IsNoErr(AudioQueueSetParameter(inAQ, kAudioQueueParam_Pan, pan), "set pan = \(pan)")
    }
}
