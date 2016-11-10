import Foundation
import AVFoundation

/**
 flash.net.NetStreamInfo for Swift
 */
public struct RTMPStreamInfo {
    public internal(set) var byteCount:Int64 = 0
    public internal(set) var resourceName:String? = nil
    public internal(set) var currentBytesPerSecond:Int32 = 0

    private var previousByteCount:Int64 = 0

    mutating func on(timer:Timer) {
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

extension RTMPStreamInfo: CustomStringConvertible {
    // MARK: CustomStringConvertible
    public var description:String {
        return Mirror(reflecting: self).description
    }
}

// MARK: -
/**
 flash.net.NetStream for Swift
 */
open class RTMPStream: NetStream {

    open static var rootPath:String = NSTemporaryDirectory()

    /**
     NetStatusEvent#info.code for NetStream
     */
    public enum Code: String {
        case bufferEmpty               = "NetStream.Buffer.Empty"
        case bufferFlush               = "NetStream.Buffer.Flush"
        case bufferFull                = "NetStream.Buffer.Full"
        case connectClosed             = "NetStream.Connect.Closed"
        case connectFailed             = "NetStream.Connect.Failed"
        case connectRejected           = "NetStream.Connect.Rejected"
        case connectSuccess            = "NetStream.Connect.Success"
        case drmUpdateNeeded           = "NetStream.DRM.UpdateNeeded"
        case failed                    = "NetStream.Failed"
        case multicastStreamReset      = "NetStream.MulticastStream.Reset"
        case pauseNotify               = "NetStream.Pause.Notify"
        case playFailed                = "NetStream.Play.Failed"
        case playFileStructureInvalid  = "NetStream.Play.FileStructureInvalid"
        case playInsufficientBW        = "NetStream.Play.InsufficientBW"
        case playNoSupportedTrackFound = "NetStream.Play.NoSupportedTrackFound"
        case playReset                 = "NetStream.Play.Reset"
        case playStart                 = "NetStream.Play.Start"
        case playStop                  = "NetStream.Play.Stop"
        case playStreamNotFound        = "NetStream.Play.StreamNotFound"
        case playTransition            = "NetStream.Play.Transition"
        case playUnpublishNotify       = "NetStream.Play.UnpublishNotify"
        case publishBadName            = "NetStream.Publish.BadName"
        case publishIdle               = "NetStream.Publish.Idle"
        case publishStart              = "NetStream.Publish.Start"
        case recordAlreadyExists       = "NetStream.Record.AlreadyExists"
        case recordFailed              = "NetStream.Record.Failed"
        case recordNoAccess            = "NetStream.Record.NoAccess"
        case recordStart               = "NetStream.Record.Start"
        case recordStop                = "NetStream.Record.Stop"
        case recordDiskQuotaExceeded   = "NetStream.Record.DiskQuotaExceeded"
        case secondScreenStart         = "NetStream.SecondScreen.Start"
        case secondScreenStop          = "NetStream.SecondScreen.Stop"
        case seekFailed                = "NetStream.Seek.Failed"
        case seekInvalidTime           = "NetStream.Seek.InvalidTime"
        case seekNotify                = "NetStream.Seek.Notify"
        case stepNotify                = "NetStream.Step.Notify"
        case unpauseNotify             = "NetStream.Unpause.Notify"
        case unpublishSuccess          = "NetStream.Unpublish.Success"
        case videoDimensionChange      = "NetStream.Video.DimensionChange"

        public var level:String {
            switch self {
            case .bufferEmpty:
                return "status"
            case .bufferFlush:
                return "status"
            case .bufferFull:
                return "status"
            case .connectClosed:
                return "status"
            case .connectFailed:
                return "error"
            case .connectRejected:
                return "error"
            case .connectSuccess:
                return "status"
            case .drmUpdateNeeded:
                return "status"
            case .failed:
                return "error"
            case .multicastStreamReset:
                return "status"
            case .pauseNotify:
                return "status"
            case .playFailed:
                return "error"
            case .playFileStructureInvalid:
                return "error"
            case .playInsufficientBW:
                return "warning"
            case .playNoSupportedTrackFound:
                return "status"
            case .playReset:
                return "status"
            case .playStart:
                return "status"
            case .playStop:
                return "status"
            case .playStreamNotFound:
                return "status"
            case .playTransition:
                return "status"
            case .playUnpublishNotify:
                return "status"
            case .publishBadName:
                return "error"
            case .publishIdle:
                return "status"
            case .publishStart:
                return "status"
            case .recordAlreadyExists:
                return "status"
            case .recordFailed:
                return "error"
            case .recordNoAccess:
                return "error"
            case .recordStart:
                return "status"
            case .recordStop:
                return "status"
            case .recordDiskQuotaExceeded:
                return "error"
            case .secondScreenStart:
                return "status"
            case .secondScreenStop:
                return "status"
            case .seekFailed:
                return "error"
            case .seekInvalidTime:
                return "error"
            case .seekNotify:
                return "status"
            case .stepNotify:
                return "status"
            case .unpauseNotify:
                return "status"
            case .unpublishSuccess:
                return "status"
            case .videoDimensionChange:
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
        case append        = "append"
        case appendAndWait = "appendAndWait"
        case reset         = "reset"
        case resume        = "resume"
        case stop          = "stop"
        case swap          = "swap"
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
        case record = "record"
        case append = "append"
        case appendWithGap = "appendWithGap"
        case live = "live"
        case localRecord = "localRecord"
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
    open fileprivate(set) dynamic var currentFPS:UInt16 = 0
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
                send(handlerName: "@setDataFrame", arguments: "onMetaData", createMetaData())
                mixer.audioIO.encoder.startRunning()
                mixer.videoIO.encoder.startRunning()
                sampler?.startRunning()
                if (howToPublish == .localRecord) {
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
    fileprivate var sampler:MP4Sampler? = nil
    fileprivate var frameCount:UInt16 = 0
    fileprivate var chunkTypes:[FLVTagType:Bool] = [:]
    fileprivate var dispatcher:IEventDispatcher!
    fileprivate var howToPublish:RTMPStream.HowToPublish = .live
    fileprivate var rtmpConnection:RTMPConnection

    public init(connection: RTMPConnection) {
        self.rtmpConnection = connection
        super.init()
        self.dispatcher = EventDispatcher(target: self)
        rtmpConnection.addEventListener(Event.RTMP_STATUS, selector: #selector(RTMPStream.on(status:)), observer: self)
        if (rtmpConnection.connected) {
            rtmpConnection.createStream(self)
        }
    }

    open func receiveAudio(flag:Bool) {
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

    open func receiveVideo(flag:Bool) {
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
                        streamId: RTMPChunk.StreamID.audio.rawValue,
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

    open func publish(_ name:String?, type:RTMPStream.HowToPublish = .live) {
        lockQueue.async {
            guard let name:String = name else {
                guard self.readyState == .publishing else {
                    self.howToPublish = type
                    switch type {
                    case .localRecord:
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
                self.sampler?.stopRunning()
                self.mixer.recorder.stopRunning()
                self.FCUnpublish()
                self.rtmpConnection.socket.doOutput(chunk: RTMPChunk(
                    type: .zero,
                    streamId: RTMPChunk.StreamID.audio.rawValue,
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
            self.sampler?.delegate = self.muxer
            self.mixer.startRunning()
            self.chunkTypes.removeAll()
            self.FCPublish()
            self.rtmpConnection.socket.doOutput(chunk: RTMPChunk(
                type: .zero,
                streamId: RTMPChunk.StreamID.audio.rawValue,
                message: RTMPCommandMessage(
                    streamId: self.id,
                    transactionId: 0,
                    objectEncoding: self.objectEncoding,
                    commandName: "publish",
                    commandObject: nil,
                    arguments: [name, type == .localRecord ? RTMPStream.HowToPublish.live.rawValue : type.rawValue]
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
                streamId: RTMPChunk.StreamID.command.rawValue,
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

    open func send(handlerName:String, arguments:Any?...) {
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

    func append(url:URL, completionHandler: MP4Sampler.Handler? = nil) {
        lockQueue.async {
            if (self.sampler == nil) {
                self.sampler = MP4Sampler()
                self.sampler?.delegate = self.muxer
                switch self.readyState {
                case .publishing:
                    self.sampler?.startRunning()
                default:
                    break
                }
            }
            self.sampler?.append(file: url, completionHandler: completionHandler)
        }
    }

    func on(timer:Timer) {
        currentFPS = frameCount
        frameCount = 0
        info.on(timer: timer)
    }

    @objc private func on(status:Notification) {
        let e:Event = Event.from(status)
        guard let data:ASObject = e.data as? ASObject, let code:String = data["code"] as? String else {
            return
        }
        switch code {
        case RTMPConnection.Code.connectSuccess.rawValue:
            readyState = .initilized
            rtmpConnection.createStream(self)
        case RTMPStream.Code.publishStart.rawValue:
            readyState = .publishing
        default:
            break
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

extension RTMPStream: IEventDispatcher {
    // MARK: IEventDispatcher
    public func addEventListener(_ type:String, selector:Selector, observer:AnyObject? = nil, useCapture:Bool = false) {
        dispatcher.addEventListener(type, selector: selector, observer: observer, useCapture: useCapture)
    }
    public func removeEventListener(_ type:String, selector:Selector, observer:AnyObject? = nil, useCapture:Bool = false) {
        dispatcher.removeEventListener(type, selector: selector, observer: observer, useCapture: useCapture)
    }
    public func dispatch(event:Event) {
        dispatcher.dispatch(event: event)
    }
    public func dispatch(_ type:String, bubbles:Bool, data:Any?) {
        dispatcher.dispatch(type, bubbles: bubbles, data: data)
    }
}

extension RTMPStream: RTMPMuxerDelegate {
    // MARK: RTMPMuxerDelegate
    func sampleOutput(audio buffer:Data, withTimestamp:Double, muxer:RTMPMuxer) {
        guard readyState == .publishing else {
            return
        }
        let type:FLVTagType = .audio
        let length:Int = rtmpConnection.socket.doOutput(chunk: RTMPChunk(
            type: chunkTypes[type] == nil ? .zero : .one,
            streamId: type.streamId,
            message: type.message(with: id, timestamp: UInt32(audioTimestamp), buffer: buffer)
        ))
        chunkTypes[type] = true
        OSAtomicAdd64(Int64(length), &info.byteCount)
        audioTimestamp = withTimestamp + (audioTimestamp - floor(audioTimestamp))
    }

    func sampleOutput(video buffer:Data, withTimestamp:Double, muxer:RTMPMuxer) {
        guard readyState == .publishing else {
            return
        }
        let type:FLVTagType = .video
        let length:Int = rtmpConnection.socket.doOutput(chunk: RTMPChunk(
            type: chunkTypes[type] == nil ? .zero : .one,
            streamId: type.streamId,
            message: type.message(with: id, timestamp: UInt32(videoTimestamp), buffer: buffer)
        ))
        chunkTypes[type] = true
        OSAtomicAdd64(Int64(length), &info.byteCount)
        videoTimestamp = withTimestamp + (videoTimestamp - floor(videoTimestamp))
        frameCount += 1
    }
}
