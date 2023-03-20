import AVFoundation

/// An object that provides the interface to control a one-way channel over a RtmpConnection.
open class RTMPStream: NetStream {
    /// NetStatusEvent#info.code for NetStream
    /// - seealso: https://help.adobe.com/en_US/air/reference/html/flash/events/NetStatusEvent.html#NET_STATUS
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

        public var level: String {
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
                return "error"
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

        func data(_ description: String) -> ASObject {
            [
                "code": rawValue,
                "level": level,
                "description": description
            ]
        }
    }

    /// The type of publish options.
    public enum HowToPublish: String {
        /// Publish with server-side recording.
        case record
        /// Publish with server-side recording which is to append file if exists.
        case append
        /// Publish with server-side recording which is to append and ajust time file if exists.
        case appendWithGap
        /// Publish.
        case live
    }

    enum ReadyState: UInt8 {
        case initialized
        case open
        case play
        case playing
        case publish
        case publishing
    }

    static let defaultID: UInt32 = 0
    /// The NetStreamInfo object whose properties contain data.
    public internal(set) var info = RTMPStreamInfo()
    /// The object encoding (AMF). Framework supports AMF0 only.
    public private(set) var objectEncoding: RTMPObjectEncoding = RTMPConnection.defaultObjectEncoding
    /// The number of frames per second being displayed.
    @objc public private(set) dynamic var currentFPS: UInt16 = 0
    /// Specifies the controls sound.
    public var soundTransform: SoundTransform {
        get {
            mixer.audioIO.soundTransform
        }
        set {
            mixer.audioIO.soundTransform = newValue
        }
    }
    /// Incoming audio plays on the stream or not.
    open var receiveAudio = true {
        didSet {
            lockQueue.async {
                guard self.readyState == .playing else {
                    return
                }
                self.rtmpConnection?.socket.doOutput(chunk: RTMPChunk(message: RTMPCommandMessage(
                    streamId: self.id,
                    transactionId: 0,
                    objectEncoding: self.objectEncoding,
                    commandName: "receiveAudio",
                    commandObject: nil,
                    arguments: [self.receiveAudio]
                )))
            }
        }
    }
    /// Incoming video plays on the stream or not.
    open var receiveVideo = true {
        didSet {
            lockQueue.async {
                guard self.readyState == .playing else {
                    return
                }
                self.rtmpConnection?.socket.doOutput(chunk: RTMPChunk(message: RTMPCommandMessage(
                    streamId: self.id,
                    transactionId: 0,
                    objectEncoding: self.objectEncoding,
                    commandName: "receiveVideo",
                    commandObject: nil,
                    arguments: [self.receiveVideo]
                )))
            }
        }
    }
    /// Pauses playback or publish of a video stream or not.
    open var paused = false {
        didSet {
            lockQueue.async {
                switch self.readyState {
                case .publish, .publishing:
                    self.hasVideo = self.paused
                    self.hasAudio = self.paused
                default:
                    break
                }
            }
        }
    }
    var id: UInt32 = RTMPStream.defaultID
    var readyState: ReadyState = .initialized {
        didSet {
            guard oldValue != readyState else {
                return
            }
            didChangeReadyState(readyState, oldValue: oldValue)
        }
    }
    var audioTimestamp: Double = 0.0
    var audioTimestampZero: Double = -1.0
    var videoTimestamp: Double = 0.0
    var videoTimestampZero: Double = -1.0
    private let muxer = RTMPMuxer()
    private var messages: [RTMPCommandMessage] = []
    private var frameCount: UInt16 = 0
    private var dispatcher: EventDispatcherConvertible!
    private var audioWasSent = false
    private var videoWasSent = false
    private var howToPublish: RTMPStream.HowToPublish = .live
    private weak var rtmpConnection: RTMPConnection?

    /// Creates a new stream.
    public init(connection: RTMPConnection) {
        self.rtmpConnection = connection
        super.init()
        dispatcher = EventDispatcher(target: self)
        connection.streams.append(self)
        addEventListener(.rtmpStatus, selector: #selector(on(status:)), observer: self)
        rtmpConnection?.addEventListener(.rtmpStatus, selector: #selector(on(status:)), observer: self)
        if rtmpConnection?.connected == true {
            rtmpConnection?.createStream(self)
        }
    }

    deinit {
        mixer.stopRunning()
        removeEventListener(.rtmpStatus, selector: #selector(on(status:)), observer: self)
        rtmpConnection?.removeEventListener(.rtmpStatus, selector: #selector(on(status:)), observer: self)
    }

    /// Plays a live stream from RTMPServer.
    open func play(_ arguments: Any?...) {
        // swiftlint:disable closure_body_length
        lockQueue.async {
            guard let name: String = arguments.first as? String else {
                switch self.readyState {
                case .play, .playing:
                    self.info.resourceName = nil
                    self.close(withLockQueue: false)
                default:
                    break
                }
                return
            }

            self.info.resourceName = name
            let message = RTMPCommandMessage(
                streamId: self.id,
                transactionId: 0,
                objectEncoding: self.objectEncoding,
                commandName: "play",
                commandObject: nil,
                arguments: arguments
            )

            switch self.readyState {
            case .initialized:
                self.messages.append(message)
            default:
                self.readyState = .play
                self.rtmpConnection?.socket.doOutput(chunk: RTMPChunk(message: message))
            }
        }
    }

    /// Seeks the keyframe.
    open func seek(_ offset: Double) {
        lockQueue.async {
            guard self.readyState == .playing else {
                return
            }
            self.rtmpConnection?.socket.doOutput(chunk: RTMPChunk(message: RTMPCommandMessage(
                streamId: self.id,
                transactionId: 0,
                objectEncoding: self.objectEncoding,
                commandName: "seek",
                commandObject: nil,
                arguments: [offset]
            )))
        }
    }

    /// Sends streaming audio, vidoe and data message from client.
    open func publish(_ name: String?, type: RTMPStream.HowToPublish = .live) {
        // swiftlint:disable closure_body_length
        lockQueue.async {
            guard let name: String = name else {
                switch self.readyState {
                case .publish, .publishing:
                    self.close(withLockQueue: false)
                default:
                    break
                }
                return
            }

            if self.info.resourceName == name && self.readyState == .publishing {
                self.howToPublish = type
                return
            }

            self.info.resourceName = name
            self.howToPublish = type

            let message = RTMPCommandMessage(
                streamId: self.id,
                transactionId: 0,
                objectEncoding: self.objectEncoding,
                commandName: "publish",
                commandObject: nil,
                arguments: [name, type.rawValue]
            )

            switch self.readyState {
            case .initialized:
                self.messages.append(message)
            default:
                self.readyState = .publish
                self.rtmpConnection?.socket.doOutput(chunk: RTMPChunk(message: message))
            }
        }
    }

    /// Stops playing or publishing and makes available other uses.
    open func close() {
        close(withLockQueue: true)
    }

    /// Sends a message on a published stream to all subscribing clients.
    open func send(handlerName: String, arguments: Any?...) {
        lockQueue.async {
            guard let rtmpConnection = self.rtmpConnection, self.readyState == .publishing else {
                return
            }
            let length = rtmpConnection.socket.doOutput(chunk: RTMPChunk(message: RTMPDataMessage(
                streamId: self.id,
                objectEncoding: self.objectEncoding,
                handlerName: handlerName,
                arguments: arguments
            )))
            self.info.byteCount.mutate { $0 += Int64(length) }
        }
    }

    /// Creates flv metadata for a stream.
    open func createMetaData() -> ASObject {
        var metadata: [String: Any] = [:]
        #if os(iOS) || os(macOS)
        if mixer.videoIO.capture.device != nil {
            metadata["width"] = mixer.videoIO.codec.settings.videoSize.width
            metadata["height"] = mixer.videoIO.codec.settings.videoSize.height
            metadata["framerate"] = mixer.videoIO.frameRate
            metadata["videocodecid"] = FLVVideoCodec.avc.rawValue
            metadata["videodatarate"] = mixer.videoIO.codec.settings.bitRate / 1000
        }
        if mixer.audioIO.capture.device != nil {
            metadata["audiocodecid"] = FLVAudioCodec.aac.rawValue
            metadata["audiodatarate"] = mixer.audioIO.codec.settings.bitRate / 1000
            if let sampleRate = mixer.audioIO.codec.inSourceFormat?.mSampleRate {
                metadata["audiosamplerate"] = sampleRate
            }
        }
        #endif
        return metadata
    }

    func close(withLockQueue: Bool) {
        if withLockQueue {
            lockQueue.sync {
                self.close(withLockQueue: false)
            }
            return
        }
        guard let rtmpConnection, ReadyState.open.rawValue < readyState.rawValue else {
            return
        }
        readyState = .open
        rtmpConnection.socket?.doOutput(chunk: RTMPChunk(
                                            type: .zero,
                                            streamId: RTMPChunk.StreamID.command.rawValue,
                                            message: RTMPCommandMessage(
                                                streamId: 0,
                                                transactionId: 0,
                                                objectEncoding: self.objectEncoding,
                                                commandName: "closeStream",
                                                commandObject: nil,
                                                arguments: [self.id]
                                            )))
    }

    func on(timer: Timer) {
        currentFPS = frameCount
        frameCount = 0
        info.on(timer: timer)
    }

    private func didChangeReadyState(_ readyState: ReadyState, oldValue: ReadyState) {
        guard let rtmpConnection else {
            return
        }

        switch oldValue {
        case .playing:
            mixer.stopDecoding()
        case .publishing:
            FCUnpublish()
            mixer.stopEncoding()
        default:
            break
        }

        switch readyState {
        case .open:
            currentFPS = 0
            frameCount = 0
            info.clear()
            for message in messages {
                rtmpConnection.currentTransactionId += 1
                message.streamId = id
                message.transactionId = rtmpConnection.currentTransactionId
                switch message.commandName {
                case "play":
                    self.readyState = .play
                case "publish":
                    self.readyState = .publish
                default:
                    break
                }
                rtmpConnection.socket.doOutput(chunk: RTMPChunk(message: message))
            }
            messages.removeAll()
        case .play:
            videoTimestamp = 0
            videoTimestampZero = -1.0
            audioTimestamp = 0
            audioTimestampZero = -1.0
            mixer.delegate = self
            mixer.startDecoding(rtmpConnection.audioEngine)
        case .publish:
            muxer.dispose()
            muxer.delegate = self
            mixer.startRunning()
            videoWasSent = false
            audioWasSent = false
            FCPublish()
        case .publishing:
            send(handlerName: "@setDataFrame", arguments: "onMetaData", createMetaData())
            mixer.startEncoding(muxer)
        default:
            break
        }
    }

    @objc
    private func on(status: Notification) {
        guard let rtmpConnection else {
            return
        }
        let e = Event.from(status)
        guard let data = e.data as? ASObject, let code = data["code"] as? String else {
            return
        }
        switch code {
        case RTMPConnection.Code.connectSuccess.rawValue:
            readyState = .initialized
            rtmpConnection.createStream(self)
        case RTMPStream.Code.playReset.rawValue:
            readyState = .play
        case RTMPStream.Code.playStart.rawValue:
            readyState = .playing
        case RTMPStream.Code.publishStart.rawValue:
            readyState = .publishing
        default:
            break
        }
    }
}

extension RTMPStream {
    func FCPublish() {
        guard let rtmpConnection, let name = info.resourceName, rtmpConnection.flashVer.contains("FMLE/") else {
            return
        }
        rtmpConnection.call("FCPublish", responder: nil, arguments: name)
    }

    func FCUnpublish() {
        guard let rtmpConnection, let name = info.resourceName, rtmpConnection.flashVer.contains("FMLE/") else {
            return
        }
        rtmpConnection.call("FCUnpublish", responder: nil, arguments: name)
    }
}

extension RTMPStream: EventDispatcherConvertible {
    // MARK: IEventDispatcher
    public func addEventListener(_ type: Event.Name, selector: Selector, observer: AnyObject? = nil, useCapture: Bool = false) {
        dispatcher.addEventListener(type, selector: selector, observer: observer, useCapture: useCapture)
    }

    public func removeEventListener(_ type: Event.Name, selector: Selector, observer: AnyObject? = nil, useCapture: Bool = false) {
        dispatcher.removeEventListener(type, selector: selector, observer: observer, useCapture: useCapture)
    }

    public func dispatch(event: Event) {
        dispatcher.dispatch(event: event)
    }

    public func dispatch(_ type: Event.Name, bubbles: Bool, data: Any?) {
        dispatcher.dispatch(type, bubbles: bubbles, data: data)
    }
}

extension RTMPStream: RTMPMuxerDelegate {
    // MARK: RTMPMuxerDelegate
    func muxer(_ muxer: RTMPMuxer, didSetMetadata: ASObject) {
        send(handlerName: "@setDataFrame", arguments: "onMetaData", didSetMetadata)
    }

    func muxer(_ muxer: RTMPMuxer, didOutputAudio buffer: Data, withTimestamp: Double) {
        guard let rtmpConnection, readyState == .publishing else {
            return
        }
        let type: FLVTagType = .audio
        let length = rtmpConnection.socket.doOutput(chunk: RTMPChunk(
            type: audioWasSent ? .one : .zero,
            streamId: type.streamId,
            message: RTMPAudioMessage(streamId: id, timestamp: UInt32(audioTimestamp), payload: buffer)
        ))
        audioWasSent = true
        info.byteCount.mutate { $0 += Int64(length) }
        audioTimestamp = withTimestamp + (audioTimestamp - floor(audioTimestamp))
    }

    func muxer(_ muxer: RTMPMuxer, didOutputVideo buffer: Data, withTimestamp: Double) {
        guard let rtmpConnection, readyState == .publishing else {
            return
        }
        let type: FLVTagType = .video
        let length = rtmpConnection.socket.doOutput(chunk: RTMPChunk(
            type: videoWasSent ? .one : .zero,
            streamId: type.streamId,
            message: RTMPVideoMessage(streamId: id, timestamp: UInt32(videoTimestamp), payload: buffer)
        ))
        if !videoWasSent {
            logger.debug("first video frame was sent")
        }
        videoWasSent = true
        info.byteCount.mutate { $0 += Int64(length) }
        videoTimestamp = withTimestamp + (videoTimestamp - floor(videoTimestamp))
        frameCount += 1
    }

    func muxer(_ muxer: RTMPMuxer, videoCodecErrorOccurred error: VideoCodec.Error) {
        delegate?.stream(self, videoCodecErrorOccurred: error)
    }

    func muxer(_ muxer: RTMPMuxer, audioCodecErrorOccurred error: AudioCodec.Error) {
        delegate?.stream(self, audioCodecErrorOccurred: error)
    }
}

extension RTMPStream: IOMixerDelegate {
    // MARK: IOMixerDelegate
    func mixer(_ mixer: IOMixer, didOutput video: CMSampleBuffer) {
        frameCount += 1
        delegate?.stream(self, didOutput: video)
    }

    func mixer(_ mixer: IOMixer, didOutput audio: AVAudioPCMBuffer, presentationTimeStamp: CMTime) {
        delegate?.stream(self, didOutput: audio, presentationTimeStamp: presentationTimeStamp)
    }

    #if os(iOS)
    func mixer(_ mixer: IOMixer, sessionWasInterrupted session: AVCaptureSession, reason: AVCaptureSession.InterruptionReason) {
        delegate?.stream(self, sessionWasInterrupted: session, reason: reason)
    }

    func mixer(_ mixer: IOMixer, sessionInterruptionEnded session: AVCaptureSession, reason: AVCaptureSession.InterruptionReason) {
        delegate?.stream(self, sessionInterruptionEnded: session, reason: reason)
    }
    #endif
}
