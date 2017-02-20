import lf
import Foundation
import CoreMedia

public class RTMPBroadcaster : RTMPConnection {
    public var streamName:String? = nil

    public lazy var stream:RTMPStream = {
        return RTMPStream(connection: self)
    }()

    fileprivate lazy var spliter:SoundSpliter = {
        var spliter:SoundSpliter = SoundSpliter()
        spliter.delegate = self
        return spliter
    }()
    private var connecting:Bool = false
    private let lockQueue:DispatchQueue = DispatchQueue(label: "com.github.shogo4405.lf.RTMPBroadcaster.lock")

    public override init() {
        super.init()
        addEventListener(Event.RTMP_STATUS, selector: #selector(RTMPBroadcaster.rtmpStatusEvent(_:)), observer: self)
    }

    deinit {
        removeEventListener(Event.RTMP_STATUS, selector: #selector(RTMPBroadcaster.rtmpStatusEvent(_:)), observer: self)
    }

    open override func connect(_ command: String, arguments: Any?...) {
        lockQueue.sync {
            if (connecting) {
                return
            }
            connecting = true
            spliter.clear()
            super.connect(command, arguments: arguments)
        }
    }
    
    open func appendSampleBuffer(_ sampleBuffer:CMSampleBuffer, withType: CMSampleBufferType, options:[NSObject: AnyObject]? = nil) {
        switch withType {
        case .video:
            stream.appendSampleBuffer(sampleBuffer, withType: .video)
        case .audio:
            spliter.appendSampleBuffer(sampleBuffer)
        }
    }

    open func processMP4Clip(mp4ClipURL: URL?, completionHandler: MP4Sampler.Handler? = nil) {
        guard let url:URL = mp4ClipURL else {
            completionHandler?()
            return
        }
        stream.appendFile(url, completionHandler: completionHandler)
    }
    
    open override func close() {
        lockQueue.sync {
            self.connecting = false
            super.close()
        }
    }

    open func rtmpStatusEvent(_ status:Notification) {
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

extension RTMPBroadcaster: SoundSpliterDelegate {
    public func outputSampleBuffer(_ sampleBuffer:CMSampleBuffer) {
        stream.appendSampleBuffer(sampleBuffer, withType: .audio)
    }
}
