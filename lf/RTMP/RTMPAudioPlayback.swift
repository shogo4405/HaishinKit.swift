import Foundation
import AudioToolbox

final class RTMPAudioPlayback: AudioQueuePlayback {
    func onMessage(message:RTMPAudioMessage) {
        guard message.codec.isSupported else {
            return
        }
    }
}
