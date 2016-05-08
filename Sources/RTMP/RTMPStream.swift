import Foundation
import AVFoundation

public class RTMPStream: EventDispatcher {

    public static var rootPath:String = NSTemporaryDirectory()

    public enum Code:String {
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

    enum ReadyState:UInt8 {
        case Initilized = 0
        case Open = 1
        case Play = 2
        case Playing = 3
        case Publish = 4
        case Publishing = 5
        case Closed = 6
    }

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

    static let defaultID:UInt32 = 0
    public static let defaultAudioBitrate:UInt32 = AACEncoder.defaultBitrate
    public static let defaultVideoBitrate:UInt32 = AVCEncoder.defaultBitrate

    public private(set) var objectEncoding:UInt8 = RTMPConnection.defaultObjectEncoding

    public var soundTransform:SoundTransform {
        get { return audioPlayback.soundTransform }
        set { audioPlayback.soundTransform = newValue }
    }

    #if os(iOS)
    public var torch:Bool {
        get { return mixer.videoIO.torch }
        set { mixer.videoIO.torch = newValue }
    }
    public var syncOrientation:Bool {
        get { return mixer.syncOrientation }
        set { mixer.syncOrientation = newValue }
    }
    #endif

    public var view:VideoIOView {
        return mixer.videoIO.view
    }

    public var audioSettings:[String: AnyObject] {
        get { return mixer.audioIO.encoder.dictionaryWithValuesForKeys(AACEncoder.supportedSettingsKeys)}
        set { mixer.audioIO.encoder.setValuesForKeysWithDictionary(newValue) }
    }

    public var videoSettings:[String: AnyObject] {
        get { return mixer.videoIO.encoder.dictionaryWithValuesForKeys(AVCEncoder.supportedSettingsKeys)}
        set { mixer.videoIO.encoder.setValuesForKeysWithDictionary(newValue)}
    }

    public var captureSettings:[String: AnyObject] {
        get { return mixer.dictionaryWithValuesForKeys(AVMixer.supportedSettingsKeys)}
        set { dispatch_async(lockQueue) { self.mixer.setValuesForKeysWithDictionary(newValue)}}
    }

    var id:UInt32 = RTMPStream.defaultID
    var readyState:ReadyState = .Initilized {
        didSet {
            switch readyState {
            case .Publishing:
                mixer.audioIO.encoder.startRunning()
                mixer.videoIO.encoder.startRunning()
            case .Closed:
                mixer.audioIO.encoder.stopRunning()
                mixer.videoIO.encoder.stopRunning()
            default:
                break
            }
        }
    }

    private(set) var recorder:RTMPRecorder = RTMPRecorder()
    private(set) var audioPlayback:RTMPAudioPlayback = RTMPAudioPlayback()

    private var muxer:RTMPMuxer = RTMPMuxer()
    private var chunkTypes:[FLVTag.TagType:Bool] = [:]
    var audioTimestamp:Double = 0
    var videoTimestamp:Double = 0
    private var rtmpConnection:RTMPConnection
    private(set) var mixer:AVMixer = AVMixer()

    private let lockQueue:dispatch_queue_t = dispatch_queue_create(
        "com.github.shogo4405.lf.RTMPStream.lock", DISPATCH_QUEUE_SERIAL
    )

    public init(rtmpConnection: RTMPConnection) {
        self.rtmpConnection = rtmpConnection
        super.init()
        mixer.audioIO.encoder.delegate = muxer
        mixer.videoIO.encoder.delegate = muxer
        rtmpConnection.addEventListener(Event.RTMP_STATUS, selector: #selector(RTMPStream.rtmpStatusHandler(_:)), observer: self)
        if (rtmpConnection.connected) {
            rtmpConnection.createStream(self)
        }
    }

    public func attachAudio(audio:AVCaptureDevice?) {
        dispatch_async(lockQueue) {
            self.mixer.audioIO.attachAudio(audio)
        }
    }

    public func attachCamera(camera:AVCaptureDevice?) {
        dispatch_async(lockQueue) {
            self.mixer.videoIO.attachCamera(camera)
            self.mixer.startRunning()
        }
    }

    public func attachScreen(screen:ScreenCaptureSession?) {
        dispatch_async(lockQueue) {
            self.mixer.videoIO.attachScreen(screen)
        }
    }

    public func receiveAudio(flag:Bool) {
        dispatch_async(lockQueue) {
            guard self.readyState == .Playing else {
                return
            }
            self.rtmpConnection.doWrite(RTMPChunk(message: RTMPCommandMessage(
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
            self.rtmpConnection.doWrite(RTMPChunk(message: RTMPCommandMessage(
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
            self.rtmpConnection.doWrite(RTMPChunk(message: RTMPCommandMessage(
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
            self.rtmpConnection.doWrite(RTMPChunk(message: RTMPCommandMessage(
                streamId: self.id,
                transactionId: 0,
                objectEncoding: self.objectEncoding,
                commandName: "play",
                commandObject: nil,
                arguments: arguments
            )))
        }
    }

    public func publish(name:String?) {
        self.publish(name, type: "live")
    }

    public func seek(offset:Double) {
        dispatch_async(lockQueue) {
            guard self.readyState == .Playing else {
                return
            }
            self.rtmpConnection.doWrite(RTMPChunk(message: RTMPCommandMessage(
                streamId: self.id,
                transactionId: 0,
                objectEncoding: self.objectEncoding,
                commandName: "seek",
                commandObject: nil,
                arguments: [offset]
            )))
        }
    }
    
    public func publish(name:String?, type:String) {
        dispatch_async(lockQueue) {
            guard let name:String = name else {
                return
            }

            while (self.readyState == .Initilized) {
                usleep(100)
            }

            self.muxer.dispose()
            self.muxer.delegate = self
            self.mixer.startRunning()
            self.chunkTypes.removeAll(keepCapacity: false)
            self.rtmpConnection.doWrite(RTMPChunk(
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
        dispatch_async(lockQueue) {
            if (self.readyState == .Closed) {
                return
            }
            self.rtmpConnection.doWrite(RTMPChunk(
                type: .Zero,
                streamId: RTMPChunk.audio,
                message: RTMPCommandMessage(
                    streamId: self.id,
                    transactionId: 0,
                    objectEncoding: self.objectEncoding,
                    commandName: "deleteStream",
                    commandObject: nil,
                    arguments: [self.id]
            )))
            self.recorder.close()
            self.audioPlayback.stopRunning()
            self.readyState = .Closed
        }
    }
    
    public func send(handlerName:String, arguments:Any?...) {
        dispatch_async(lockQueue) {
            if (self.readyState == .Closed) {
                return
            }
            self.rtmpConnection.doWrite(RTMPChunk(message: RTMPDataMessage(
                streamId: self.id,
                objectEncoding: self.objectEncoding,
                handlerName: handlerName,
                arguments: arguments
            )))
        }
    }

    public func registerEffect(video effect:VisualEffect) -> Bool {
        return mixer.videoIO.registerEffect(effect)
    }

    public func unregisterEffect(video effect:VisualEffect) -> Bool {
        return mixer.videoIO.unregisterEffect(effect)
    }

    public func setPointOfInterest(focus:CGPoint, exposure:CGPoint) {
        mixer.videoIO.focusPointOfInterest = focus
        mixer.videoIO.exposurePointOfInterest = exposure
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

// MARK: - RTMPMuxerDelegate
extension RTMPStream: RTMPMuxerDelegate {
    func sampleOutput(muxer:RTMPMuxer, audio buffer:NSData, timestamp:Double) {
        let type:FLVTag.TagType = .Audio
        rtmpConnection.doWrite(RTMPChunk(
            type: chunkTypes[type] == nil ? .Zero : .One,
            streamId: type.streamId,
            message: type.createMessage(id, timestamp: UInt32(audioTimestamp), buffer: buffer)
        ))
        chunkTypes[type] = true
        audioTimestamp = timestamp + (audioTimestamp - floor(audioTimestamp))
    }

    func sampleOutput(muxer:RTMPMuxer, video buffer:NSData, timestamp:Double) {
        let type:FLVTag.TagType = .Video
        rtmpConnection.doWrite(RTMPChunk(
            type: chunkTypes[type] == nil ? .Zero : .One,
            streamId: type.streamId,
            message: type.createMessage(id, timestamp: UInt32(videoTimestamp), buffer: buffer)
        ))
        chunkTypes[type] = true
        videoTimestamp = timestamp + (videoTimestamp - floor(videoTimestamp))
    }
}
