import UIKit
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
        case Append = "append"
        case AppendAndWait = "appendAndWait"
        case Reset = "reset"
        case Resume = "resume"
        case Stop = "stop"
        case Swap = "swap"
        case Switch = "switch"
    }

    public enum RecordOption: String {
        case New = "new"
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
            var description:String = "RTMPStreamPlayOptions{"
            description += "len:\(len),"
            description += "offset:\(offset),"
            description += "oldStreamName:\(oldStreamName),"
            description += "start:\(start),"
            description += "streamName:\(streamName),"
            description += "transition:\(transition.rawValue)"
            description += "}"
            return description
        }
    }

    static let defaultID:UInt32 = 0
    public static let defaultAudioBitrate:UInt32 = AACEncoder.defaultBitrate
    public static let defaultVideoBitrate:UInt32 = AVCEncoder.defaultBitrate

    public private(set) var objectEncoding:UInt8 = RTMPConnection.defaultObjectEncoding

    public var torch:Bool {
        get {
            return captureManager.torch
        }
        set {
            captureManager.torch = newValue
        }
    }

    public var soundTransform:SoundTransform {
        get {
            return audioPlayback.soundTransform
        }
        set {
            audioPlayback.soundTransform = newValue
        }
    }

    public var syncOrientation:Bool {
        get {
            return captureManager.syncOrientation
        }
        set {
            captureManager.syncOrientation = newValue
        }
    }

    private var _view:UIView? = nil
    public var view:UIView! {
        if (_view == nil) {
            layer.videoGravity = videoGravity
            captureManager.videoIO.layer.videoGravity = videoGravity
            _view = UIView()
            _view!.backgroundColor = UIColor.blackColor()
            _view!.layer.addSublayer(captureManager.videoIO.layer)
            _view!.layer.addSublayer(layer)
            _view!.addObserver(self, forKeyPath: "frame", options: NSKeyValueObservingOptions.New, context: nil)
        }
        return _view!
    }

    public var videoGravity:String! = AVLayerVideoGravityResizeAspectFill {
        didSet {
            layer.videoGravity = videoGravity
            captureManager.videoIO.layer.videoGravity = videoGravity
        }
    }

    public var audioSettings:[String: AnyObject] {
        get {
            return captureManager.audioIO.encoder.dictionaryWithValuesForKeys(AACEncoder.supportedSettingsKeys)
        }
        set {
            captureManager.audioIO.encoder.setValuesForKeysWithDictionary(newValue)
        }
    }

    public var videoSettings:[String: AnyObject] {
        get {
            return captureManager.videoIO.encoder.dictionaryWithValuesForKeys(AVCEncoder.supportedSettingsKeys)
        }
        set {
            captureManager.videoIO.encoder.setValuesForKeysWithDictionary(newValue)
        }
    }

    public var captureSettings:[String: AnyObject] {
        get {
            return captureManager.dictionaryWithValuesForKeys(AVCaptureSessionManager.supportedSettingsKeys)
        }
        set {
            dispatch_async(lockQueue) {
                self.captureManager.setValuesForKeysWithDictionary(newValue)
            }
        }
    }

    var id:UInt32 = RTMPStream.defaultID
    var readyState:ReadyState = .Initilized {
        didSet {
            switch readyState {
            case .Publishing:
                send("@setDataFrame", arguments: "onMetaData", muxer.createMetadata(captureManager))
                captureManager.audioIO.encoder.startRunning()
                captureManager.videoIO.encoder.startRunning()
            case .Closed:
                captureManager.audioIO.encoder.stopRunning()
                captureManager.videoIO.encoder.stopRunning()
            default:
                break
            }
        }
    }

    var readyForKeyframe:Bool = false
    var videoFormatDescription:CMVideoFormatDescriptionRef?

    private(set) var recorder:RTMPRecorder = RTMPRecorder()
    private(set) var audioPlayback:RTMPAudioPlayback = RTMPAudioPlayback()

    private var layer:AVSampleBufferDisplayLayer = AVSampleBufferDisplayLayer()
    private var muxer:RTMPMuxer = RTMPMuxer()
    private var chunkTypes:[FLVTag.TagType:Bool] = [:]
    private var audioTimestamp:Double = 0
    private var videoTimestamp:Double = 0
    private var rtmpConnection:RTMPConnection
    private var captureManager:AVCaptureSessionManager = AVCaptureSessionManager()

    private let lockQueue:dispatch_queue_t = dispatch_queue_create(
        "com.github.shogo4405.lf.RTMPStream.lock", DISPATCH_QUEUE_SERIAL
    )

    public init(rtmpConnection: RTMPConnection) {
        self.rtmpConnection = rtmpConnection
        super.init()
        captureManager.audioIO.encoder.delegate = muxer
        captureManager.videoIO.encoder.delegate = muxer
        rtmpConnection.addEventListener(Event.RTMP_STATUS, selector: "rtmpStatusHandler:", observer: self)
        if (rtmpConnection.connected) {
            rtmpConnection.createStream(self)
        }
    }

    deinit {
        _view?.removeObserver(self, forKeyPath: "frame")
    }

    public func attachAudio(audio:AVCaptureDevice?) {
        dispatch_async(lockQueue) {
            self.captureManager.attachAudio(audio)
        }
    }

    public func attachCamera(camera:AVCaptureDevice?) {
        dispatch_async(lockQueue) {
            self.captureManager.attachCamera(camera)
            self.captureManager.startRunning()
        }
    }

    public func attachScreen(screen:ScreenCaptureSession?) {
        dispatch_async(lockQueue) {
            self.captureManager.attachScreen(screen)
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
            self.readyForKeyframe = false
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
            self.readyForKeyframe = false
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
            self.captureManager.startRunning()
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
        return captureManager.videoIO.registerEffect(effect)
    }

    public func unregisterEffect(video effect:VisualEffect) -> Bool {
        return captureManager.videoIO.unregisterEffect(effect)
    }

    public func setPointOfInterest(focus:CGPoint, exposure:CGPoint) {
        captureManager.focusPointOfInterest = focus
        captureManager.exposurePointOfInterest = exposure
    }

    func enqueueSampleBuffer(video sampleBuffer:CMSampleBuffer) {
        dispatch_async(dispatch_get_main_queue()) {
            if (self.readyForKeyframe && self.layer.readyForMoreMediaData) {
                self.layer.enqueueSampleBuffer(sampleBuffer)
                self.layer.setNeedsDisplay()
            }
        }
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

    override public func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        guard let keyPath:String = keyPath else {
            return
        }
        switch keyPath {
        case "frame":
            layer.frame = view.bounds
            captureManager.videoIO.layer.frame = view.bounds
        default:
            break
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
