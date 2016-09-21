import Foundation
import AudioToolbox

final class RTMPAudioPlayback: AudioStreamPlayback {
    private var config:AudioSpecificConfig?

    func on(message:RTMPAudioMessage) {
        guard message.codec.isSupported else {
            return
        }
        if let config:AudioSpecificConfig = message.createAudioSpecificConfig() {
            fileTypeHint = kAudioFileAAC_ADTSType
            self.config = config
            return
        }
        message.config = config
        parseBytes(message.soundData)
    }
}
