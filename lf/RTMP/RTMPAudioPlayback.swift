import Foundation
import AudioToolbox

final class RTMPAudioPlayback: AudioStreamPlayback {
    func onMessage(message:RTMPAudioMessage) {
        guard message.codec.isSupported else {
            return
        }
        /*
        if let formatDescription:AudioStreamBasicDescription = message.createFormatDescription() {
            self.formatDescription = formatDescription
        }
        parseBytes(message.soundData)
        */
    }
}
