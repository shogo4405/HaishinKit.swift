import ReplayKit
import Foundation

@available(iOS 10.0, *)
public class RTMPBroadcaster: RTMPConnection {
    static let `default`:RTMPBroadcaster = RTMPBroadcaster()

    public var streamName:String? = nil

    fileprivate lazy var stream:RTMPStream = {
        return RTMPStream(connection: self)
    }()
    private var connecting:Bool = false
    private let lockQueue:DispatchQueue = DispatchQueue(label: "com.github.shogo4405.lf.RTMPBroadcaster.lock")

    override public func connect(_ command: String, arguments: Any?...) {
        lockQueue.sync {
            if (connecting) {
                return
            }
            connecting = true
            super.connect(command, arguments: arguments)
        }
    }

    override public func close() {
        lockQueue.sync {
            self.connecting = false
            super.close()
        }
    }

    func processMP4Clip(mp4ClipURL: URL?, completionHandler: MP4Sampler.Handler? = nil) {
        guard let url:URL = mp4ClipURL else {
            completionHandler?()
            return
        }
        stream.appendFile(url, completionHandler: completionHandler)
    }

    override func on(status:Notification) {
        super.on(status: status)
        let e:Event = Event.from(status)
        guard
            let data:ASObject = e.data as? ASObject,
            let code:String = data["code"] as? String,
            let streamName:String = streamName else {
            return
        }
        switch code {
        case RTMPConnection.Code.connectSuccess.rawValue:
            stream.publish(streamName)
        default:
            break
        }
    }
}

@available(iOS 10.0, *)
open class RTMPSampleHandler: RPBroadcastSampleHandler {
    override open func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        super.broadcastStarted(withSetupInfo: setupInfo)
        guard
            let endpointURL:String = setupInfo?["endpointURL"] as? String,
            let streamName:String = setupInfo?["streamName"] as? String else {
            return
        }
        RTMPBroadcaster.default.streamName = streamName
        RTMPBroadcaster.default.connect(endpointURL, arguments: nil)
    }

    override open func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        super.processSampleBuffer(sampleBuffer, with: sampleBufferType)
        guard RTMPBroadcaster.default.stream.readyState == .publishing else {
            return
        }
        switch sampleBufferType {
        case .video:
            RTMPBroadcaster.default.stream.mixer.videoIO.captureOutput(nil, didOutputSampleBuffer: sampleBuffer, from: nil)
        case .audioApp:
            RTMPBroadcaster.default.stream.mixer.audioIO.captureOutput(nil, didOutputSampleBuffer: sampleBuffer, from: nil)
            break
        case .audioMic:
            break
        }
    }
}

@available(iOS 10.0, *)
open class RTMPMP4ClipHandler: RPBroadcastMP4ClipHandler {
    override open func processMP4Clip(with mp4ClipURL: URL?, setupInfo: [String : NSObject]?, finished: Bool) {
        guard
            let endpointURL:String = setupInfo?["endpointURL"] as? String,
            let streamName:String = setupInfo?["streamName"] as? String else {
            return
        }
        RTMPBroadcaster.default.streamName = streamName
        RTMPBroadcaster.default.connect(endpointURL, arguments: nil)
        if (finished) {
            RTMPBroadcaster.default.processMP4Clip(mp4ClipURL: mp4ClipURL) {_ in
                if (finished) {
                    RTMPBroadcaster.default.close()
                }
            }
            return
        }
        RTMPBroadcaster.default.processMP4Clip(mp4ClipURL: mp4ClipURL)
    }
}
