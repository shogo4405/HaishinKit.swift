import ReplayKit
import VideoToolbox
import Foundation

@available(iOS 10.0, *)
public class RTMPBroadcaster: RTMPConnection {
    public var streamName:String? = nil

    public lazy var stream:RTMPStream = {
        return RTMPStream(connection: self)
    }()

    fileprivate lazy var soundMixer:SoundMixer = {
        var soundMixer:SoundMixer = SoundMixer()
        soundMixer.delegate = self
        return soundMixer
    }()
    private var connecting:Bool = false
    private let lockQueue:DispatchQueue = DispatchQueue(label: "com.github.shogo4405.lf.RTMPBroadcaster.lock")

    open override func connect(_ command: String, arguments: Any?...) {
        lockQueue.sync {
            if (connecting) {
                return
            }
            connecting = true
            soundMixer.clear()
            super.connect(command, arguments: arguments)
        }
    }

    open func appendSampleBuffer(_ sampleBuffer:CMSampleBuffer, withType: CMSampleBufferType, options:[NSObject: AnyObject]? = nil) {
        guard stream.readyState == .publishing else {
            return
        }
        switch withType {
        case .video:
            stream.mixer.videoIO.captureOutput(nil, didOutputSampleBuffer: sampleBuffer, from: nil)
        case .audio:
            guard let channel:Int = options?["channel" as NSObject] as? Int else {
                break
            }
            soundMixer.appendSampleBuffer(sampleBuffer, withChannel: channel)
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

    open override func on(status:Notification) {
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
extension RTMPBroadcaster: SoundMixerDelegate {
    func outputSampleBuffer(_ sampleBuffer:CMSampleBuffer) {
        stream.mixer.audioIO.captureOutput(nil, didOutputSampleBuffer: sampleBuffer, from: nil)
    }
}

