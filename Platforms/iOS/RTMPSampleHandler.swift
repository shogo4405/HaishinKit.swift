import ReplayKit
import Foundation

@available(iOS 10.0, *)
public class RTMPBroadcaster: RTMPConnection {
    internal var stream:RTMPStream?
    internal var formatDescriptions:[RPSampleBufferType:CMFormatDescription] = [:]

    override init() {
        super.init()
    }

    override public func connect(withCommand: String, arguments: Any?...) {
        addEventListener(type: Event.RTMP_STATUS, selector: #selector(RTMPBroadcaster.on(status:)), observer: self)
        super.connect(withCommand: withCommand, arguments: arguments)
    }

    override public func close() {
        super.close()
        removeEventListener(type: Event.RTMP_STATUS, selector: #selector(RTMPBroadcaster.on(status:)), observer: self)
        formatDescriptions.removeAll()
    }

    internal func process(sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard let stream:RTMPStream = stream, stream.readyState == .publishing else {
            return
        }
        switch  sampleBufferType {
        case .video:
            stream.mixer.videoIO.captureOutput(nil, didOutputSampleBuffer: sampleBuffer, from: nil)
        case .audioApp:
            stream.mixer.audioIO.captureOutput(nil, didOutputSampleBuffer: sampleBuffer, from: nil)
        default:
            break
        }
    }

    @objc private func on(status:Notification) {
        let e:Event = Event.from(status)
        guard let data:ASObject = e.data as? ASObject, let code:String = data["code"] as? String else {
            return
        }
        switch code {
        case RTMPConnection.Code.connectSuccess.rawValue:
            stream = RTMPStream(connection: self)
            stream?.publish(withName: "live")
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
        RTMPSampleHandler.broadcaster?.connect(withCommand: endpointURL)
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
