import Foundation
import AVFoundation

final class AudioSessionUtil {
    private init() {
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
