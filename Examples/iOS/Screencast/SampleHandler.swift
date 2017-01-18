import lf
import VideoToolbox
import ReplayKit

@available(iOS 10.0, *)
open class SampleHandler: RPBroadcastSampleHandler {
    private var broadcaster:RTMPBroadcaster = RTMPBroadcaster()

    public override init() {
        super.init()
        print(self)
    }

    deinit {
        print(self)
    }

    override open func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        super.broadcastStarted(withSetupInfo: setupInfo)
        guard
            let endpointURL:String = setupInfo?["endpointURL"] as? String,
            let streamName:String = setupInfo?["streamName"] as? String else {
            return
        }
        broadcaster.streamName = streamName
        broadcaster.connect(endpointURL, arguments: nil)
    }

    override open func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case .video:
            if let description:CMVideoFormatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) {
                let dimensions:CMVideoDimensions = CMVideoFormatDescriptionGetDimensions(description)
                broadcaster.stream.videoSettings = [
                    "width": dimensions.width,
                    "height": dimensions.height ,
                    "profileLevel": kVTProfileLevel_H264_Baseline_AutoLevel,
                ]
            }

            broadcaster.appendSampleBuffer(sampleBuffer, withType: .video)
        case .audioApp:
            broadcaster.appendSampleBuffer(sampleBuffer, withType: .audio, options: ["channel" as NSObject: 0 as AnyObject])
        case .audioMic:
            broadcaster.appendSampleBuffer(sampleBuffer, withType: .audio, options: ["channel" as NSObject: 1 as AnyObject])
        }
    }
}
