import Foundation
import AVFoundation

/**
 flash.net.NetStreamInfo for Swift
 */
public struct RTMPStreamInfo {
    public internal(set) var byteCount:Int64 = 0
    public internal(set) var resourceName:String? = nil
    public internal(set) var currentBytesPerSecond:Int32 = 0

    fileprivate var previousByteCount:Int64 = 0

    mutating func didTimerInterval(_ timer:Timer) {
        let byteCount:Int64 = self.byteCount
        currentBytesPerSecond = Int32(byteCount - previousByteCount)
        previousByteCount = byteCount
    }

    mutating func clear() {
        byteCount = 0
        currentBytesPerSecond = 0
        previousByteCount = 0
    }
}

// MARK: CustomStringConvertible
extension RTMPStreamInfo: CustomStringConvertible {
    public var description:String {
        return Mirror(reflecting: self).description
    }
}

// MARK: -
/**
 flash.net.NetStream for Swift
 */
open class RTMPStream: Stream {

    open static var rootPath:String = NSTemporaryDirectory()

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

        func data(_ description:String) -> ASObject {
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

    public enum HowToPublish: String {
        case Record = "record"
        case Append = "append"
        case AppendWithGap = "appendWithGap"
        case Live = "live"
        case LocalRecord = "localRecord"
    }

    enum ReadyState: UInt8 {
        case initilized = 0
        case open       = 1
        case play       = 2
        case playing    = 3
        case publish    = 4
        case publishing = 5
        case closed     = 6
    }

    static let defaultID:UInt32 = 0
    open static let defaultAudioBitrate:UInt32 = AACEncoder.defaultBitrate
    open static let defaultVideoBitrate:UInt32 = AVCEncoder.defaultBitrate
    open internal(set) var info:RTMPStreamInfo = RTMPStreamInfo()
    open fileprivate(set) var objectEncoding:UInt8 = RTMPConnection.defaultObjectEncoding
    open fileprivate(set) dynamic var currentFPS:UInt8 = 0
    open var soundTransform:SoundTransform {
        get { return audioPlayback.soundTransform }
        set { audioPlayback.soundTransform = newValue }
    }

    var id:UInt32 = RTMPStream.defaultID
    var readyState:ReadyState = .initilized {
        didSet {
            switch readyState {
            case .open:
                currentFPS = 0
                frameCount = 0
                info.clear()
            case .publishing:
                send("@setDataFrame", arguments: "onMetaData", createMetaData())
                mixer.audioIO.encoder.startRunning()
                mixer.videoIO.encoder.startRunning()
                if (howToPublish == .LocalRecord) {
                    mixer.recorder.fileName = info.resourceName
                    mixer.recorder.startRunning()
                }
            default:
                break
            }
        }
    }

    var audioTimestamp:Double = 0
    var videoTimestamp:Double = 0

    fileprivate(set) var audioPlayback:RTMPAudioPlayback = RTMPAudioPlayback()
    fileprivate var muxer:RTMPMuxer = RTMPMuxer()
    fileprivate var frameCount:UInt8 = 0
    fileprivate var chunkTypes:[FLVTag.TagType:Bool] = [:]
    fileprivate var dispatcher:IEventDispatcher!
    fileprivate var howToPublish:RTMPStream.HowToPublish = .Live
    fileprivate var rtmpConnection:RTMPConnection

    public init(rtmpConnection: RTMPConnection) {
        self.rtmpConnection = rtmpConnection
        super.init()
        self.dispatcher = EventDispatcher(target: self)
        rtmpConnection.addEventListener(Event.RTMP_STATUS, selector: #selector(RTMPStream.rtmpStatusHandler(_:)), observer: self)
        if (rtmpConnection.connected) {
            rtmpConnection.createStream(self)
        }
    }

    open func receiveAudio(_ flag:Bool) {
        lockQueue.async {
            guard self.readyState == .playing else {
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

    open func receiveVideo(_ flag:Bool) {
        lockQueue.async {
            guard self.readyState == .playing else {
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

    open func play(_ arguments:Any?...) {
        lockQueue.async {
            guard let name:String = arguments.first as? String else {
                switch self.readyState {
                case .play:
                    fallthrough
                case .playing:
                    self.audioPlayback.stopRunning()
                    self.rtmpConnection.socket.doOutput(chunk: RTMPChunk(
                        type: .zero,
                        streamId: RTMPChunk.audio,
                        message: RTMPCommandMessage(
                            streamId: self.id,
                            transactionId: 0,
                            objectEncoding: self.objectEncoding,
                            commandName: "closeStream",
                            commandObject: nil,
                            arguments: []
                        )))
                default:
                    break
                }
                return
            }
            while (self.readyState == .initilized) {
                usleep(100)
            }
            self.audioPlayback.startRunning()
            self.info.resourceName = name
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

    open func seek(_ offset:Double) {
        lockQueue.async {
            guard self.readyState == .playing else {
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

    @available(*, unavailable)
    open func publish(_ name:String?, type:String = "live") {
        guard let howToPublish:RTMPStream.HowToPublish = RTMPStream.HowToPublish(rawValue: type) else {
            return
        }
        publish(name, type: howToPublish)
    }

    open func publish(_ name:String?, type:RTMPStream.HowToPublish = .Live) {
        lockQueue.async {
            guard let name:String = name else {
                guard self.readyState == .publishing else {
                    self.howToPublish = type
                    switch type {
                    case .LocalRecord:
                        self.mixer.recorder.fileName = self.info.resourceName
                        self.mixer.recorder.startRunning()
                    default:
                        break
                    }
                    return
                }
                self.readyState = .open
                #if os(iOS)
                self.mixer.videoIO.screen?.stopRunning()
                #endif
                self.mixer.audioIO.encoder.delegate = nil
                self.mixer.videoIO.encoder.delegate = nil
                self.mixer.audioIO.encoder.stopRunning()
                self.mixer.videoIO.encoder.stopRunning()
                self.mixer.recorder.stopRunning()
                self.FCUnpublish()
                self.rtmpConnection.socket.doOutput(chunk: RTMPChunk(
                    type: .zero,
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

            while (self.readyState == .initilized) {
                usleep(100)
            }

            self.info.resourceName = name
            self.howToPublish = type
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
                type: .zero,
                streamId: RTMPChunk.audio,
                message: RTMPCommandMessage(
                    streamId: self.id,
                    transactionId: 0,
                    objectEncoding: self.objectEncoding,
                    commandName: "publish",
                    commandObject: nil,
                    arguments: [name, type == .LocalRecord ? RTMPStream.HowToPublish.Live.rawValue : type.rawValue]
            )))

            self.readyState = .publish
        }
    }

    open func close() {
        if (self.readyState == .closed) {
            return
        }
        play()
        publish(nil)
        lockQueue.sync {
            self.rtmpConnection.socket.doOutput(chunk: RTMPChunk(
                type: .zero,
                streamId: RTMPChunk.command,
                message: RTMPCommandMessage(
                    streamId: 0,
                    transactionId: 0,
                    objectEncoding: self.objectEncoding,
                    commandName: "deleteStream",
                    commandObject: nil,
                    arguments: [self.id]
            )))
            self.readyState = .closed
        }
    }

    open func send(_ handlerName:String, arguments:Any?...) {
        lockQueue.async {
            if (self.readyState == .closed) {
                return
            }
            let length:Int = self.rtmpConnection.socket.doOutput(chunk: RTMPChunk(message: RTMPDataMessage(
                streamId: self.id,
                objectEncoding: self.objectEncoding,
                handlerName: handlerName,
                arguments: arguments
            )))
            OSAtomicAdd64(Int64(length), &self.info.byteCount)
        }
    }

    open func createMetaData() -> ASObject {
        var metadata:ASObject = [:]
        if let _:AVCaptureInput = mixer.videoIO.input {
            metadata["width"] = mixer.videoIO.encoder.width
            metadata["height"] = mixer.videoIO.encoder.height
            metadata["framerate"] = mixer.videoIO.fps
            metadata["videocodecid"] = FLVVideoCodec.avc.rawValue
            metadata["videodatarate"] = mixer.videoIO.encoder.bitrate
        }
        if let _:AVCaptureInput = mixer.audioIO.input {
            metadata["audiocodecid"] = FLVAudioCodec.aac.rawValue
            metadata["audiodatarate"] = mixer.audioIO.encoder.bitrate
        }
        return metadata
    }

    func didTimerInterval(_ timer:Timer) {
        currentFPS = frameCount
        frameCount = 0
        info.didTimerInterval(timer)
    }

    func rtmpStatusHandler(_ notification:Notification) {
        let e:Event = Event.from(notification)
        if let data:ASObject = e.data as? ASObject, let code:String = data["code"] as? String {
            switch code {
            case RTMPConnection.Code.ConnectSuccess.rawValue:
                readyState = .initilized
                rtmpConnection.createStream(self)
            case RTMPStream.Code.PublishStart.rawValue:
                readyState = .publishing
            default:
                break
            }
        }
    }
}

extension RTMPStream {
    func FCPublish() {
        guard let name:String = info.resourceName , rtmpConnection.flashVer.contains("FMLE/") else {
            return
        }
        rtmpConnection.call("FCPublish", responder: nil, arguments: name)
    }

    func FCUnpublish() {
        guard let name:String = info.resourceName , rtmpConnection.flashVer.contains("FMLE/") else {
            return
        }
        rtmpConnection.call("FCUnpublish", responder: nil, arguments: name)
    }
}

// MARK: - IEventDispatcher
extension RTMPStream: IEventDispatcher {
    public func addEventListener(_ type:String, selector:Selector, observer:AnyObject? = nil, useCapture:Bool = false) {
        dispatcher.addEventListener(type, selector: selector, observer: observer, useCapture: useCapture)
    }
    public func removeEventListener(_ type:String, selector:Selector, observer:AnyObject? = nil, useCapture:Bool = false) {
        dispatcher.removeEventListener(type, selector: selector, observer: observer, useCapture: useCapture)
    }
    public func dispatchEvent(_ e:Event) {
        dispatcher.dispatchEvent(e)
    }
    public func dispatchEventWith(_ type:String, bubbles:Bool, data:Any?) {
        dispatcher.dispatchEventWith(type, bubbles: bubbles, data: data)
    }
}

// MARK: - RTMPMuxerDelegate
extension RTMPStream: RTMPMuxerDelegate {
    func sampleOutput(_ muxer:RTMPMuxer, audio buffer:Data, timestamp:Double) {
        guard readyState == .publishing else {
            return
        }
        let type:FLVTag.TagType = .audio
        let length:Int = rtmpConnection.socket.doOutput(chunk: RTMPChunk(
            type: chunkTypes[type] == nil ? .zero : .one,
            streamId: type.streamId,
            message: type.createMessage(id, timestamp: UInt32(audioTimestamp), buffer: buffer)
        ))
        chunkTypes[type] = true
        OSAtomicAdd64(Int64(length), &info.byteCount)
        audioTimestamp = timestamp + (audioTimestamp - floor(audioTimestamp))
    }

    func sampleOutput(_ muxer:RTMPMuxer, video buffer:Data, timestamp:Double) {
        guard readyState == .publishing else {
            return
        }
        let type:FLVTag.TagType = .video
        let length:Int = rtmpConnection.socket.doOutput(chunk: RTMPChunk(
            type: chunkTypes[type] == nil ? .zero : .one,
            streamId: type.streamId,
            message: type.createMessage(id, timestamp: UInt32(videoTimestamp), buffer: buffer)
        ))
        chunkTypes[type] = true
        OSAtomicAdd64(Int64(length), &info.byteCount)
        videoTimestamp = timestamp + (videoTimestamp - floor(videoTimestamp))
        frameCount = (frameCount + 1) & 0xFF
    }
}
