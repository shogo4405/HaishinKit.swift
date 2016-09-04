import CoreAudio
import Foundation
import AVFoundation

final class AudioUtil {
    private init() {
    }

    static func getInputGain() -> Float32 {
        return AVAudioSession.sharedInstance().inputGain
    }

    static func setInputGain(_ volume:Float32) -> OSStatus {
        if (AVAudioSession.sharedInstance().isInputGainSettable) {
            do {
                try AVAudioSession.sharedInstance().setInputGain(volume)
            } catch {
                return -1
            }
        }
        return -1
    }

    static func startRunning() {
        #if !(arch(i386) || arch(x86_64))
            let session:AVAudioSession = AVAudioSession.sharedInstance()
            do {
                try session.setCategory(AVAudioSessionCategoryPlayback)
                try session.setActive(true)
            } catch {
            }
        #endif
    }
    
    static func stopRunning() {
        #if !(arch(i386) || arch(x86_64))
            let session:AVAudioSession = AVAudioSession.sharedInstance()
            do {
                try session.setActive(false)
            } catch {
            }
        #endif
    }
}
