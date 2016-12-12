import lf
import Foundation
import ReplayKit

class MovieClipHandler: RTMPMP4ClipHandler {
    
    override func updateServiceInfo(_ serviceInfo: [String : NSCoding & NSObjectProtocol]) {
        print("updateServiceInfo:\(serviceInfo)")
    }

    override func processMP4Clip(with mp4ClipURL: URL?, setupInfo: [String : NSObject]?, finished: Bool) {
        print("processMP4Clip:\(mp4ClipURL):\(setupInfo):\(finished)")
        super.processMP4Clip(with: mp4ClipURL, setupInfo: setupInfo, finished: finished)
    }

    override func finishedProcessingMP4Clip(withUpdatedBroadcastConfiguration broadcastConfiguration: RPBroadcastConfiguration?, error: Error?) {
        print("finishedProcessingMP4Clip:\(broadcastConfiguration):\(error)")
        super.finishedProcessingMP4Clip(withUpdatedBroadcastConfiguration: broadcastConfiguration, error: error)
    }
}
