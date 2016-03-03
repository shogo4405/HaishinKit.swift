import UIKit
import Foundation
import AVFoundation

public class RTMPStream: EventDispatcher {

    public static var rootPath:String = NSTemporaryDirectory()

    public enum Code:String {
        case RecordAlreadyExists     = "NetStream.Record.AlreadyExists"
        case RecordFailed            = "NetStream.Record.Failed"
        case RecordNoAccess          = "NetStream.Record.NoAccess"
        case RecordStart             = "NetStream.Record.Start"
        case RecordStop              = "NetStream.Record.Stop"
        case RecordDiskQuotaExceeded = "NetStream.Record.DiskQuotaExceeded"

        public var level:String {
            switch self {
            case .RecordAlreadyExists:
                return "status"
            case .RecordFailed:
                return "error"
            case .RecordNoAccess:
                return "status"
            case .RecordStart:
                return "status"
            case .RecordStop:
                return "status"
            case .RecordDiskQuotaExceeded:
                return "error"
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
        get { return captureManager.torch }
        set { captureManager.torch = newValue }
    }

    public var soundTransform:SoundTransform {
        get { return audioPlayback.soundTransform }
        set { audioPlayback.soundTransform = newValue }
    }

    public var syncOrientation:Bool {
        get { return captureManager.syncOrientation }
        set { captureManager.syncOrientation = newValue }
    }

    private var _view:UIView? = nil
    public var view:UIView! {
        if (_view == nil) {
            layer.videoGravity = videoGravity
            captureManager.layer.videoGravity = videoGravity
            _view = UIView()
            _view!.backgroundColor = UIColor.blackColor()
            _view!.layer.addSublayer(captureManager.layer)
            _view!.layer.addSublayer(layer)
            _view!.addObserver(self, forKeyPath: "frame", options: NSKeyValueObservingOptions.New, context: nil)
        }
        return _view!
    }

    public var videoGravity:String! = AVLayerVideoGravityResizeAspectFill {
        didSet {
            layer.videoGravity = videoGravity
            captureManager.layer.videoGravity = videoGravity
        }
    }

    public var audioSettings:[String: AnyObject] {
        get {
            return muxer.audioSettings
        }
        set {
            muxer.audioSettings = newValue
        }
    }

    public var videoSettings:[String: AnyObject] {
        get {
            return muxer.videoSettings
        }
        set {
            muxer.videoSettings = newValue
        }
    }

    public var captureSettings:[String: AnyObject] {
        get {
            return captureManager.dictionaryWithValuesForKeys(AVCaptureSessionManager.supportedSettingsKeys)
        }
        set {
            captureManager.setValuesForKeysWithDictionary(newValue)
        }
    }

    var id:UInt32 = RTMPStream.defaultID
    var readyState:ReadyState = .Initilized {
        didSet {
            switch readyState {
            case .Publishing:
                send("@setDataFrame", arguments: "onMetaData", muxer.createMetadata(captureManager.currentAudio, captureManager.currentCamera))
                captureManager.audioDataOutput.setSampleBufferDelegate(muxer.audioEncoder, queue: muxer.audioEncoder.lockQueue)
                captureManager.videoDataOutput.setSampleBufferDelegate(muxer.videoEncoder, queue: muxer.videoEncoder.lockQueue)
            case .Closed:
                captureManager.audioDataOutput.setSampleBufferDelegate(nil, queue: nil)
                captureManager.videoDataOutput.setSampleBufferDelegate(nil, queue: nil)
            default:
                break
            }
        }
    }

    var readyForKeyframe:Bool = false
    var videoFormatDescription:CMVideoFormatDescriptionRef?
    private(set) lazy var recorder:RTMPRecorder = RTMPRecorder()
    private(set) lazy var audioPlayback:RTMPAudioPlayback = RTMPAudioPlayback()

    private var audioTimestamp:Double = 0
    private var videoTimestamp:Double = 0
    private var rtmpConnection:RTMPConnection
    private var chunkTypes:[FLVTag.TagType:Bool] = [:]
    private lazy var layer:AVSampleBufferDisplayLayer = AVSampleBufferDisplayLayer()
    private lazy var muxer:RTMPMuxer = RTMPMuxer()
    private var captureManager:AVCaptureSessionManager = AVCaptureSessionManager()
    private let lockQueue:dispatch_queue_t = dispatch_queue_create("com.github.shogo4405.lf.RTMPStream.lock", DISPATCH_QUEUE_SERIAL)

    public init(rtmpConnection: RTMPConnection) {
        self.rtmpConnection = rtmpConnection
        super.init()
        rtmpConnection.addEventListener(Event.RTMP_STATUS, selector: "rtmpStatusHandler:", observer: self)
        if (rtmpConnection.connected) {
            rtmpConnection.createStream(self)
        }
    }

    deinit {
        _view?.removeObserver(self, forKeyPath: "frame")
    }

    public func attachAudio(audio:AVCaptureDevice?) {
        captureManager.attachAudio(audio)
    }

    public func attachCamera(camera:AVCaptureDevice?) {
        captureManager.attachCamera(camera)
        if (readyState == .Publishing) {
            captureManager.videoDataOutput.setSampleBufferDelegate(muxer.videoEncoder, queue: muxer.videoEncoder.lockQueue)
        }
        captureManager.startRunning()
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
            if (name == nil) {
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
                    arguments: [name!, type]
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
            self.readyState = .Closed
        }
    }
    
    public func send(handlerName:String, arguments:Any?...) {
        if (readyState == .Closed) {
            return
        }
        rtmpConnection.doWrite(RTMPChunk(message: RTMPDataMessage(
            streamId: id,
            objectEncoding: objectEncoding,
            handlerName: handlerName,
            arguments: arguments
        )))
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
            case "NetStream.Publish.Start":
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
            captureManager.layer.frame = view.bounds
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
