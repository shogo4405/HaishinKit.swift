import Foundation
import AVFoundation
import CoreAudio

final class AudioUtil {

    private static var defaultDeviceID:AudioObjectID {
        var deviceID:AudioObjectID = AudioObjectID(0)
        var size:UInt32 = UInt32(MemoryLayout<AudioObjectID>.size)
        var address:AudioObjectPropertyAddress = AudioObjectPropertyAddress()
        address.mSelector = kAudioHardwarePropertyDefaultOutputDevice;
        address.mScope = kAudioObjectPropertyScopeGlobal;
        address.mElement = kAudioObjectPropertyElementMaster;
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)
        return deviceID
    }

    private init() {
    }

    static func setInputGain(_ volume:Float32) -> OSStatus {
        var inputVolume:Float32 = volume
        let size:UInt32 = UInt32(MemoryLayout<Float32>.size)
        var address:AudioObjectPropertyAddress = AudioObjectPropertyAddress()
        address.mSelector = kAudioDevicePropertyVolumeScalar
        address.mScope = kAudioObjectPropertyScopeGlobal
        address.mElement = kAudioObjectPropertyElementMaster
        return AudioObjectSetPropertyData(defaultDeviceID, &address, 0, nil, size, &inputVolume)
    }

    static func getInputGain() -> Float32{
        var volume:Float32 = 0.5
        var size:UInt32 = UInt32(MemoryLayout<Float32>.size)
        var address:AudioObjectPropertyAddress = AudioObjectPropertyAddress()
        address.mSelector = kAudioDevicePropertyVolumeScalar
        address.mScope = kAudioObjectPropertyScopeGlobal
        address.mElement = kAudioObjectPropertyElementMaster
        AudioObjectGetPropertyData(defaultDeviceID, &address, 0, nil, &size, &volume)
        return volume
    }
    
    static func startRunning() {
    }
    
    static func stopRunning() {
    }
}
