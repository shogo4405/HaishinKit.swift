import AVFoundation
import CoreMedia
import HaishinKit

public class RTMPBroadcaster: RTMPConnection {
    public var streamName: String?

    public lazy var stream: RTMPStream = {
        RTMPStream(connection: self)
    }()

    private var connecting: Bool = false
    private let lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.RTMPBroadcaster.lock")

    override public init() {
        super.init()
        addEventListener(.rtmpStatus, selector: #selector(rtmpStatusEvent), observer: self)
    }

    deinit {
        removeEventListener(.rtmpStatus, selector: #selector(rtmpStatusEvent), observer: self)
    }

    override public func connect(_ command: String, arguments: Any?...) {
        lockQueue.sync {
            if connecting {
                return
            }
            connecting = true
            super.connect(command, arguments: arguments)
        }
    }

    func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer, withType: AVMediaType, options: [NSObject: AnyObject]? = nil) {
        stream.appendSampleBuffer(sampleBuffer, withType: withType)
    }

    override public func close() {
        lockQueue.sync {
            self.connecting = false
            super.close()
        }
    }

    @objc
    func rtmpStatusEvent(_ status: Notification) {
        let e = Event.from(status)
        guard
            let data: ASObject = e.data as? ASObject,
            let code: String = data["code"] as? String,
            let streamName: String = streamName else {
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
