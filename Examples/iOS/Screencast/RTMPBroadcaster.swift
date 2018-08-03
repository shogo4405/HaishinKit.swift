import HaishinKit
import CoreMedia

public class RTMPBroadcaster: RTMPConnection {
    public var streamName: String?

    public lazy var stream: RTMPStream = {
        return RTMPStream(connection: self)
    }()

    private lazy var spliter: SoundSpliter = {
        var spliter: SoundSpliter = SoundSpliter()
        spliter.delegate = self
        return spliter
    }()
    private var connecting: Bool = false
    private let lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.RTMPBroadcaster.lock")

    public override init() {
        super.init()
        addEventListener(Event.RTMP_STATUS, selector: #selector(rtmpStatusEvent), observer: self)
    }

    deinit {
        removeEventListener(Event.RTMP_STATUS, selector: #selector(rtmpStatusEvent), observer: self)
    }

    override public func connect(_ command: String, arguments: Any?...) {
        lockQueue.sync {
            if connecting {
                return
            }
            connecting = true
            spliter.clear()
            super.connect(command, arguments: arguments)
        }
    }

    func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer, withType: CMSampleBufferType, options: [NSObject: AnyObject]? = nil) {
        stream.appendSampleBuffer(sampleBuffer, withType: withType)
    }

    override public func close() {
        lockQueue.sync {
            self.connecting = false
            super.close()
        }
    }

    @objc func rtmpStatusEvent(_ status: Notification) {
        let e: Event = Event.from(status)
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

extension RTMPBroadcaster: SoundSpliterDelegate {
    public func outputSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        stream.appendSampleBuffer(sampleBuffer, withType: .audio)
    }
}
