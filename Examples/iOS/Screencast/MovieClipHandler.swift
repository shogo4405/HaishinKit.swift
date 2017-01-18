import lf
import Foundation
import ReplayKit

class MovieClipHandler: RPBroadcastMP4ClipHandler {
    private var broadcaster:RTMPBroadcaster = RTMPBroadcaster()

    override open func processMP4Clip(with mp4ClipURL: URL?, setupInfo: [String : NSObject]?, finished: Bool) {
        guard
            let endpointURL:String = setupInfo?["endpointURL"] as? String,
            let streamName:String = setupInfo?["streamName"] as? String else {
            return
        }
        broadcaster.streamName = streamName
        broadcaster.connect(endpointURL, arguments: nil)
        if (finished) {
            broadcaster.processMP4Clip(mp4ClipURL: mp4ClipURL) {_ in
                if (finished) {
                    self.broadcaster.close()
                }
            }
            return
        }
        broadcaster.processMP4Clip(mp4ClipURL: mp4ClipURL)
    }
}

