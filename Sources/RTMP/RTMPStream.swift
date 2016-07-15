import Foundation
import AVFoundation

/**
 flash.net.NetStreamInfo for Swift
 */
public final class RTMPStreamInfo: NSObject {
    public internal(set) var byteCount:Int64 = 0
    public internal(set) var resourceName:String?
    public internal(set) var currentBytesPerSecond:Int32 = 0

    public override var description: String {
        return Mirror(reflecting: self).description
    }

    private var previousByteCount:Int64 = 0

    func didTimerInterval(timer:NSTimer) {
        let byteCount:Int64 = self.byteCount
        currentBytesPerSecond = Int32(byteCount - previousByteCount)
        previousByteCount = byteCount
    }

    func clear() {
        byteCount = 0
        resourceName = nil
        currentBytesPerSecond = 0
    }
}

// MARK: NSCopying
extension RTMPStreamInfo: NSCopying {
    public func copyWithZone(zone: NSZone) -> AnyObject {
        let info:RTMPStreamInfo = RTMPStreamInfo()
        info.resourceName = resourceName
        info.byteCount = byteCount
        info.currentBytesPerSecond = currentBytesPerSecond
        return info
    }
}

// MARK: -
/**
 flash.net.NetStream for Swift
 */
public class RTMPStream: Stream {

    public static var rootPath:String = NSTemporaryDirectory()

    /**
     NetStatusEvent#info.code for NetStream
     */
    public enum Code: String {
        case BufferEmpty               = "NetStream.Buffer.Empty"
        case BufferFlush               = "NetStream.Buffer.Flush"
        case BufferFull                = "NetStream.Buffer.Full"
        case ConnectClosed             = "NetStream.Connect.Closed"
        case ConnectFailed             = "NetStream.Connect.Failed"
        case ConnectRejected           = "NetStream.Connect.Rejected"
        case ConnectSuccess            = "NetStream.Connect.Success"
        case DRMUpdateNeeded           = "NetStream.DRM.UpdateNeeded"
        case Failed                    = "NetStream.Failed"
        case MulticastStreamReset      = "NetStream.MulticastStream.Reset"
        case PauseNotify               = "NetStream.Pause.Notify"
        case PlayFailed                = "NetStream.Play.Failed"
        case PlayFileStructureInvalid  = "NetStream.Play.FileStructureInvalid"
        case PlayInsufficientBW        = "NetStream.Play.InsufficientBW"
        case PlayNoSupportedTrackFound = "NetStream.Play.NoSupportedTrackFound"
        case PlayReset                 = "NetStream.Play.Reset"
        case PlayStart                 = "NetStream.Play.Start"
        case PlayStop                  = "NetStream.Play.Stop"
        case PlayStreamNotFound        = "NetStream.Play.StreamNotFound"
        case PlayTransition            = "NetStream.Play.Transition"
        case PlayUnpublishNotify       = "NetStream.Play.UnpublishNotify"
        case PublishBadName            = "NetStream.Publish.BadName"
        case PublishIdle               = "NetStream.Publish.Idle"
        case PublishStart              = "NetStream.Publish.Start"
        case RecordAlreadyExists       = "NetStream.Record.AlreadyExists"
        case RecordFailed              = "NetStream.Record.Failed"
        case RecordNoAccess            = "NetStream.Record.NoAccess"
        case RecordStart               = "NetStream.Record.Start"
        case RecordStop                = "NetStream.Record.Stop"
        case RecordDiskQuotaExceeded   = "NetStream.Record.DiskQuotaExceeded"
        case SecondScreenStart         = "NetStream.SecondScreen.Start"
        case SecondScreenStop          = "NetStream.SecondScreen.Stop"
        case SeekFailed                = "NetStream.Seek.Failed"
        case SeekInvalidTime           = "NetStream.Seek.InvalidTime"
        case SeekNotify                = "NetStream.Seek.Notify"
        case StepNotify                = "NetStream.Step.Notify"
        case UnpauseNotify             = "NetStream.Unpause.Notify"
        case UnpublishSuccess          = "NetStream.Unpublish.Success"
        case VideoDimensionChange      = "NetStream.Video.DimensionChange"

        public var level:String {
            switch self {
            case .BufferEmpty:
                return "status"
            case .BufferFlush:
                return "status"
            case .BufferFull:
                return "status"
            case .ConnectClosed:
                return "status"
            case .ConnectFailed:
                return "error"
            case .ConnectRejected:
                return "error"
            case .ConnectSuccess:
                return "status"
            case .DRMUpdateNeeded:
                return "status"
            case .Failed:
                return "error"
            case .MulticastStreamReset:
                return "status"
            case .PauseNotify:
                return "status"
            case .PlayFailed:
                return "error"
            case .PlayFileStructureInvalid:
                return "error"
            case .PlayInsufficientBW:
                return "warning"
            case .PlayNoSupportedTrackFound:
                return "status"
            case .PlayReset:
                return "status"
            case .PlayStart:
                return "status"
            case .PlayStop:
                return "status"
            case .PlayStreamNotFound:
                return "status"
            case .PlayTransition:
                return "status"
            case .PlayUnpublishNotify:
                return "status"
            case .PublishBadName:
                return "error"
            case .PublishIdle:
                return "status"
            case .PublishStart:
                return "status"
            case .RecordAlreadyExists:
                return "status"
            case .RecordFailed:
                return "error"
            case .RecordNoAccess:
                return "error"
            case .RecordStart:
                return "status"
            case .RecordStop:
                return "status"
            case .RecordDiskQuotaExceeded:
                return "error"
            case .SecondScreenStart:
                return "status"
            case .SecondScreenStop:
                return "status"
            case .SeekFailed:
                return "error"
            case .SeekInvalidTime:
                return "error"
            case .SeekNotify:
                return "status"
            case .StepNotify:
                return "status"
            case .UnpauseNotify:
                return "status"
            case .UnpublishSuccess:
                return "status"
            case .VideoDimensionChange:
                return "status"
            }
        }

        func data(description:String) -> ASObject {
            return [
                "code": rawValue,
                "level": level,
                "description": description,
            ]
        }
    }

    /**
     flash.net.NetStreamPlayTransitions for Swift
     */
    public enum PlayTransition: String {
        case Append        = "append"
        case AppendAndWait = "appendAndWait"
        case Reset         = "reset"
        case Resume        = "resume"
        case Stop          = "stop"
        case Swap          = "swap"
        case Switch        = "switch"
    }

    public enum RecordOption: String {
        case New    = "new"
        case Append = "append"

        func createFileHandle(path:String) -> NSFileHandle? {
            switch self {
            case .New:
                return NSFileHandle(forWritingAtPath: rootPath + path + ".flv")
            case .Append:
                return NSFileHandle(forUpdatingAtPath: rootPath + path + ".flv")
            }
        }
    }

    public struct PlayOption: CustomStringConvertible {
        public var len:Double = 0
        public var offset:Double = 0
        public var oldStreamName:String = ""
        public var start:Double = 0
        public var streamName:String = ""
        public var transition:PlayTransition = .Switch

        public var description:String {
            return Mirror(reflecting: self).description
        }
    }

    enum ReadyState: UInt8 {
        case Initilized = 0
        case Open       = 1
        case Play       = 2
        case Playing    = 3
        case Publish    = 4
        case Publishing = 5
        case Closed     = 6
    }

    static let defaultID:UInt32 = 0
    public static let defaultAudioBitrate:UInt32 = AACEncoder.defaultBitrate
    public static let defaultVideoBitrate:UInt32 = AVCEncoder.defaultBitrate

    public private(set) var objectEncoding:UInt8 = RTMPConnection.defaultObjectEncoding

    public var soundTransform:SoundTransform {
        get { return audioPlayback.soundTransform }
        set { audioPlayback.soundTransform = newValue }
    }

    dynamic public private(set) var currentFPS:UInt8 = 0

    var _info:RTMPStreamInfo = RTMPStreamInfo()
    public var info:RTMPStreamInfo {
        return _info.copy() as! RTMPStreamInfo
    }

    var id:UInt32 = RTMPStream.defaultID
    var readyState:ReadyState = .Initilized {
        didSet {
            switch readyState {
            case .Open:
                currentFPS = 0
                frameCount = 0
                _info.clear()
            case .Publishing:
                send("@setDataFrame", arguments: "onMetaData", createMetaData())
                mixer.audioIO.encoder.startRunning()
                mixer.videoIO.encoder.startRunning()
            default:
                break
            }
        }
    }

    var audioTimestamp:Double = 0
    var videoTimestamp:Double = 0

    private(set) var recorder:RTMPRecorder = RTMPRecorder()
    private(set) var audioPlayback:RTMPAudioPlayback = RTMPAudioPlayback()
    private var muxer:RTMPMuxer = RTMPMuxer()
    private var frameCount:UInt8 = 0
    private var chunkTypes:[FLVTag.TagType:Bool] = [:]
    private var dispatcher:IEventDispatcher!
    private var rtmpConnection:RTMPConnection

    public init(rtmpConnection: RTMPConnection) {
        self.rtmpConnection = rtmpConnection
        super.init()
        self.dispatcher = EventDispatcher(target: self)
        rtmpConnection.addEventListener(Event.RTMP_STATUS, selector: #selector(RTMPStream.rtmpStatusHandler(_:)), observer: self)
        if (rtmpConnection.connected) {
            rtmpConnection.createStream(self)
        }
    }

    public func receiveAudio(flag:Bool) {
        dispatch_async(lockQueue) {
            guard self.readyState == .Playing else {
                return
            }
            self.rtmpConnection.socket.doOutput(chunk: RTMPChunk(message: RTMPCommandMessage(
                streamId: self.id,
                transactionId: 0,
                objectEncoding: self.objectEncoding,
                commandName: "receiveAudio",
                commandObject: nil,
                arguments: [flag]
            )))
        }
    }

    public func receiveVideo(flag:Bool) {
        dispatch_async(lockQueue) {
            guard self.readyState == .Playing else {
                return
            }
            self.rtmpConnection.socket.doOutput(chunk: RTMPChunk(message: RTMPCommandMessage(
                streamId: self.id,
                transactionId: 0,
                objectEncoding: self.objectEncoding,
                commandName: "receiveVideo",
                commandObject: nil,
                arguments: [flag]
            )))
        }
    }

    public func play(arguments:Any?...) {
        dispatch_async(lockQueue) {
            while (self.readyState == .Initilized) {
                usleep(100)
            }
            self.audioPlayback.startRunning()
            self.rtmpConnection.socket.doOutput(chunk: RTMPChunk(message: RTMPCommandMessage(
                streamId: self.id,
                transactionId: 0,
                objectEncoding: self.objectEncoding,
                commandName: "play",
                commandObject: nil,
                arguments: arguments
            )))
        }
    }

    public func record(option:RecordOption, arguments:Any?...) {
        dispatch_async(lockQueue) {
            while (self.readyState == .Initilized) {
                usleep(100)
            }
            self.audioPlayback.startRunning()
            self.recorder.dispatcher = self
            self.recorder.open(arguments[0] as! String, option: option)
            self.rtmpConnection.socket.doOutput(chunk: RTMPChunk(message: RTMPCommandMessage(
                streamId: self.id,
                transactionId: 0,
                objectEncoding: self.objectEncoding,
                commandName: "play",
                commandObject: nil,
                arguments: arguments
            )))
        }
    }

    public func seek(offset:Double) {
        dispatch_async(lockQueue) {
            guard self.readyState == .Playing else {
                return
            }
            self.rtmpConnection.socket.doOutput(chunk: RTMPChunk(message: RTMPCommandMessage(
                streamId: self.id,
                transactionId: 0,
                objectEncoding: self.objectEncoding,
                commandName: "seek",
                commandObject: nil,
                arguments: [offset]
            )))
        }
    }

    public func publish(name:String?, _ type:String = "live") {
        dispatch_async(lockQueue) {
            guard let name:String = name else {
                guard self.readyState == .Publishing else {
                    return
                }
                self.readyState = .Open
                #if os(iOS)
                self.mixer.videoIO.screen?.stopRunning()
                #endif
                self.mixer.audioIO.encoder.delegate = nil
                self.mixer.videoIO.encoder.delegate = nil
                self.mixer.audioIO.encoder.stopRunning()
                self.mixer.videoIO.encoder.stopRunning()
                self.FCUnpublish()
                self.rtmpConnection.socket.doOutput(chunk: RTMPChunk(
                    type: .Zero,
                    streamId: RTMPChunk.audio,
                    message: RTMPCommandMessage(
                        streamId: self.id,
                        transactionId: 0,
                        objectEncoding: self.objectEncoding,
                        commandName: "closeStream",
                        commandObject: nil,
                        arguments: []
                )))
                return
            }

            while (self.readyState == .Initilized) {
                usleep(100)
            }

            self._info.resourceName = name
            self.muxer.dispose()
            self.muxer.delegate = self
            #if os(iOS)
            self.mixer.videoIO.screen?.startRunning()
            #endif
            self.mixer.audioIO.encoder.delegate = self.muxer
            self.mixer.videoIO.encoder.delegate = self.muxer
            self.mixer.startRunning()
            self.chunkTypes.removeAll()
            self.FCPublish()
            self.rtmpConnection.socket.doOutput(chunk: RTMPChunk(
                type: .Zero,
                streamId: RTMPChunk.audio,
                message: RTMPCommandMessage(
                    streamId: self.id,
                    transactionId: 0,
                    objectEncoding: self.objectEncoding,
                    commandName: "publish",
                    commandObject: nil,
                    arguments: [name, type]
            )))
            self.readyState = .Publish
        }
    }

    public func close() {
        if (self.readyState == .Closed) {
            return
        }
        publish(nil)
        dispatch_sync(lockQueue) {
            self.rtmpConnection.socket.doOutput(chunk: RTMPChunk(
                type: .Zero,
                streamId: RTMPChunk.command,
                message: RTMPCommandMessage(
                    streamId: 0,
                    transactionId: 0,
                    objectEncoding: self.objectEncoding,
                    commandName: "deleteStream",
                    commandObject: nil,
                    arguments: [self.id]
            )))
            self.readyState = .Closed
        }
    }

    public func send(handlerName:String, arguments:Any?...) {
        dispatch_async(lockQueue) {
            if (self.readyState == .Closed) {
                return
            }
            let length:Int = self.rtmpConnection.socket.doOutput(chunk: RTMPChunk(message: RTMPDataMessage(
                streamId: self.id,
                objectEncoding: self.objectEncoding,
                handlerName: handlerName,
                arguments: arguments
            )))
            OSAtomicAdd64(Int64(length), &self._info.byteCount)
        }
    }

    public func createMetaData() -> ASObject {
        var metadata:ASObject = [:]
        if let _:AVCaptureInput = mixer.videoIO.input {
            metadata["width"] = mixer.videoIO.encoder.width
            metadata["height"] = mixer.videoIO.encoder.height
            metadata["framerate"] = mixer.videoIO.fps
            metadata["videocodecid"] = FLVVideoCodec.AVC.rawValue
            metadata["videodatarate"] = mixer.videoIO.encoder.bitrate
        }
        if let _:AVCaptureInput = mixer.audioIO.input {
            metadata["audiocodecid"] = FLVAudioCodec.AAC.rawValue
            metadata["audiodatarate"] = mixer.audioIO.encoder.bitrate
        }
        return metadata
    }

    func didTimerInterval(timer:NSTimer) {
        currentFPS = frameCount
        frameCount = 0
        _info.didTimerInterval(timer)
    }

    func rtmpStatusHandler(notification:NSNotification) {
        let e:Event = Event.from(notification)
        if let data:ASObject = e.data as? ASObject, code:String = data["code"] as? String {
            switch code {
            case RTMPConnection.Code.ConnectSuccess.rawValue:
                readyState = .Initilized
                rtmpConnection.createStream(self)
            case RTMPStream.Code.PublishStart.rawValue:
                readyState = .Publishing
            default:
                break
            }
        }
    }
}

extension RTMPStream {
    func FCPublish() {
        guard let name:String = _info.resourceName where rtmpConnection.flashVer.containsString("FMLE/") else {
            return
        }
        rtmpConnection.call("FCPublish", responder: nil, arguments: name)
    }

    func FCUnpublish() {
        guard let name:String = _info.resourceName where rtmpConnection.flashVer.containsString("FMLE/") else {
            return
        }
        rtmpConnection.call("FCUnpublish", responder: nil, arguments: name)
    }
}

// MARK: - IEventDispatcher
extension RTMPStream: IEventDispatcher {
    public func addEventListener(type:String, selector:Selector, observer:AnyObject? = nil, useCapture:Bool = false) {
        dispatcher.addEventListener(type, selector: selector, observer: observer, useCapture: useCapture)
    }
    public func removeEventListener(type:String, selector:Selector, observer:AnyObject? = nil, useCapture:Bool = false) {
        dispatcher.removeEventListener(type, selector: selector, observer: observer, useCapture: useCapture)
    }
    public func dispatchEvent(e:Event) {
        dispatcher.dispatchEvent(e)
    }
    public func dispatchEventWith(type:String, bubbles:Bool, data:Any?) {
        dispatcher.dispatchEventWith(type, bubbles: bubbles, data: data)
    }
}

// MARK: - RTMPMuxerDelegate
extension RTMPStream: RTMPMuxerDelegate {
    func sampleOutput(muxer:RTMPMuxer, audio buffer:NSData, timestamp:Double) {
        guard readyState == .Publishing else {
            return
        }
        let type:FLVTag.TagType = .Audio
        let length:Int = rtmpConnection.socket.doOutput(chunk: RTMPChunk(
            type: chunkTypes[type] == nil ? .Zero : .One,
            streamId: type.streamId,
            message: type.createMessage(id, timestamp: UInt32(audioTimestamp), buffer: buffer)
        ))
        chunkTypes[type] = true
        OSAtomicAdd64(Int64(length), &_info.byteCount)
        audioTimestamp = timestamp + (audioTimestamp - floor(audioTimestamp))
    }

    func sampleOutput(muxer:RTMPMuxer, video buffer:NSData, timestamp:Double) {
        guard readyState == .Publishing else {
            return
        }
        let type:FLVTag.TagType = .Video
        let length:Int = rtmpConnection.socket.doOutput(chunk: RTMPChunk(
            type: chunkTypes[type] == nil ? .Zero : .One,
            streamId: type.streamId,
            message: type.createMessage(id, timestamp: UInt32(videoTimestamp), buffer: buffer)
        ))
        chunkTypes[type] = true
        OSAtomicAdd64(Int64(length), &_info.byteCount)
        videoTimestamp = timestamp + (videoTimestamp - floor(videoTimestamp))
        frameCount = (frameCount + 1) & 0xFF
    }
}
