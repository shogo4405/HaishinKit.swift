import ReplayKit
import Foundation

@available(iOS 10.0, *)
public class RTMPBroadcaster: RTMPConnection {
    private var stream:RTMPStream?

    func process(sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard let stream:RTMPStream = stream, stream.readyState == .publishing else {
            return
        }
        switch  sampleBufferType {
        case .video:
            stream.mixer.videoIO.captureOutput(nil, didOutputSampleBuffer: sampleBuffer, from: nil)
        case .audioApp:
            break
        case .audioMic:
            stream.mixer.audioIO.captureOutput(nil, didOutputSampleBuffer: sampleBuffer, from: nil)
        }
    }

    override func on(status:Notification) {
        super.on(status: status)
        let e:Event = Event.from(status)
        guard let data:ASObject = e.data as? ASObject, let code:String = data["code"] as? String else {
            return
        }
        switch code {
        case RTMPConnection.Code.connectSuccess.rawValue:
            stream = RTMPStream(connection: self)
            stream?.publish("live")
        default:
            break
        }
    }
}

@available(iOS 10.0, *)
open class RTMPSampleHandler: RPBroadcastSampleHandler {

    public static var broadcaster:RTMPBroadcaster?

    override open func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        logger.info("broadcastStarted:\(setupInfo)")
        guard let endpointURL:String = setupInfo?["endpointURL"] as? String else {
            return
        }
        RTMPSampleHandler.broadcaster = RTMPBroadcaster()
        RTMPSampleHandler.broadcaster?.connect(endpointURL, arguments: nil)
    }

    override open func broadcastPaused() {
        logger.info("broadcastPaused")
    }

    override open func broadcastResumed() {
        logger.info("broadcastResumed")
    }

    override open func broadcastFinished() {
        logger.info("broadcastFinished")
        RTMPSampleHandler.broadcaster?.close()
        RTMPSampleHandler.broadcaster = nil
    }

    override open func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        RTMPSampleHandler.broadcaster?.process(sampleBuffer: sampleBuffer, with: sampleBufferType)
    }
}
