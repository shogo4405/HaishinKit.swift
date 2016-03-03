import Foundation
import AudioToolbox

final class RTMPAudioPlayback: AudioStreamPlayback {
    var config:AudioSpecificConfig?

    func onMessage(message:RTMPAudioMessage) {
        guard message.codec.isSupported else {
            return
        }

        if let config:AudioSpecificConfig = message.createAudioSpecificConfig() {
            self.config = config
            return
        }

        guard let config:AudioSpecificConfig = config else {
            return
        }

        let data:[UInt8] = message.soundData
        let _:[UInt8] = config.adts(data.count)

        // parseBytes(adts + data)
    }
}
