import lf
import Foundation
import ReplayKit

class MovieClipHandler: RTMPMP4ClipHandler {

    override func processMP4Clip(with mp4ClipURL: URL?, setupInfo: [String : NSObject]?, finished: Bool) {
        print("\(mp4ClipURL):\(setupInfo):\(finished)")
        super.processMP4Clip(with: mp4ClipURL, setupInfo: setupInfo, finished: finished)
    }

    override func finishedProcessingMP4Clip(withUpdatedBroadcastConfiguration broadcastConfiguration: RPBroadcastConfiguration?, error: Error?) {
        print("\(broadcastConfiguration):\(error)")
        super.finishedProcessingMP4Clip(withUpdatedBroadcastConfiguration: broadcastConfiguration, error: error)
    }
}
