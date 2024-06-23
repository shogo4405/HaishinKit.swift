import AVFoundation

/// An object that provides the interface to control a one-way channel over a RtmpConnection.
public final class RTMPStream {
    static let aac: UInt8 = FLVAudioCodec.aac.rawValue << 4 | FLVSoundRate.kHz44.rawValue << 2 | FLVSoundSize.snd16bit.rawValue << 1 | FLVSoundType.stereo.rawValue

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
    public enum HowToPublish: String, Sendable {
        /// Publish with server-side recording.
        case record
        /// Publish with server-side recording which is to append file if exists.
        case append
        /// Publish with server-side recording which is to append and ajust time file if exists.
        case appendWithGap
        /// Publish.
        case live
    }

    static let defaultID: UInt32 = 0
    /// The RTMPStream metadata.
    public private(set) var metadata: [String: Any?] = [:]
    /// The RTMPStreamInfo object whose properties contain data.
    public internal(set) var info = RTMPStreamInfo()
    /// The object encoding (AMF). Framework supports AMF0 only.
    public private(set) var objectEncoding: RTMPObjectEncoding = RTMPConnection.defaultObjectEncoding
    /// The boolean value that indicates audio samples allow access or not.
    public private(set) var audioSampleAccess = true
    /// The boolean value that indicates video samples allow access or not.
    public private(set) var videoSampleAccess = true
    public private(set) var currentFPS: UInt16 = 0

    /// Incoming audio plays on the stream or not.
    public var receiveAudio = true {
        didSet {
            guard readyState == .playing else {
                return
            }
            connection?.doOutput(chunk: RTMPChunk(message: RTMPCommandMessage(
                streamId: self.id,
                transactionId: 0,
                objectEncoding: self.objectEncoding,
                commandName: "receiveAudio",
                commandObject: nil,
                arguments: [self.receiveAudio]
            )))
        }
    }
    /// Incoming video plays on the stream or not.
    public var receiveVideo = true {
        didSet {
            guard readyState == .playing else {
                return
            }
            connection?.doOutput(chunk: RTMPChunk(message: RTMPCommandMessage(
                streamId: self.id,
                transactionId: 0,
                objectEncoding: self.objectEncoding,
                commandName: "receiveVideo",
                commandObject: nil,
                arguments: [self.receiveVideo]
            )))
        }
    }

    /// Pauses playback or publish of a video stream or not.
    public var paused = false {
        didSet {
            switch readyState {
            case .play, .playing:
                connection?.doOutput(chunk: RTMPChunk(message: RTMPCommandMessage(
                    streamId: self.id,
                    transactionId: 0,
                    objectEncoding: self.objectEncoding,
                    commandName: "pause",
                    commandObject: nil,
                    arguments: [self.paused, floor(self.startedAt.timeIntervalSinceNow * -1000)]
                )))
            default:
                break
            }
        }
    }
    /// Specifies the stream name used for FMLE-compatible sequences.
    public var fcPublishName: String?
    public internal(set) var readyState: IOStream.ReadyState = .initialized {
        didSet {
            guard let connection else {
                return
            }
            switch readyState {
            case .open:
                currentFPS = 0
                frameCount = 0
                audioSampleAccess = true
                videoSampleAccess = true
                metadata.removeAll()
                info.clear()
                for message in messages {
                    message.streamId = id
                    message.transactionId = connection.newTransaction
                    switch message.commandName {
                    case "play":
                        self.readyState = .play
                    case "publish":
                        self.readyState = .publish
                    default:
                        break
                    }
                    connection.doOutput(chunk: RTMPChunk(message: message))
                }
                messages.removeAll()
            case .play:
                stream.startRunning()
            case .playing:
                startedAt = .init()
            case .publish:
                // bitrateStrategy.setUp()
                startedAt = .init()
            case .publishing:
                stream.startRunning()
                startedAt = .init()
                let metadata = makeMetaData()
                send(handlerName: "@setDataFrame", arguments: "onMetaData", ASArray(metadata))
                self.metadata = metadata
            default:
                break
            }
        }
    }
    var id: UInt32 = RTMPStream.defaultID
    var frameCount: UInt16 = 0
    private var messages: [RTMPCommandMessage] = []
    private var startedAt = Date() {
        didSet {
            dataTimestamps.removeAll()
        }
    }
    private lazy var dispatcher: EventDispatcher = {
        return EventDispatcher(target: self)
    }()
    private var howToPublish: RTMPStream.HowToPublish = .live
    private var dataTimestamps: [String: Date] = .init()
    private lazy var stream = IOStream()
    private weak var connection: RTMPConnection?
    private var audioTimestamp: RTMPTimestamp<AVAudioTime> = .init()
    private var videoTimestamp: RTMPTimestamp<CMTime> = .init()
    private var audioBuffer: AVAudioCompressedBuffer?
    private var continuations: [AsyncStream<CMSampleBuffer>.Continuation] = []

    private var audioFormat: AVAudioFormat? {
        didSet {
            switch readyState {
            case .publishing:
                guard let config = AudioSpecificConfig(formatDescription: audioFormat?.formatDescription) else {
                    return
                }
                var buffer = Data([Self.aac, FLVAACPacketType.seq.rawValue])
                buffer.append(contentsOf: config.bytes)
                doOutput(
                    oldValue == nil ? .zero : .one,
                    chunkStreamId: FLVTagType.audio.streamId,
                    message: RTMPAudioMessage(streamId: 0, timestamp: 0, payload: buffer)
                )
            case .playing:
                if let audioFormat {
                    audioBuffer = AVAudioCompressedBuffer(format: audioFormat, packetCapacity: 1, maximumPacketSize: 1024 * Int(audioFormat.channelCount))
                } else {
                    audioBuffer = nil
                }
            default:
                break
            }
        }
    }

    private var videoFormat: CMFormatDescription? {
        didSet {
            guard videoFormat != oldValue else {
                return
            }
            switch readyState {
            case .publishing:
                switch videoFormat?.mediaSubType {
                case .h264?:
                    guard let configurationBox = videoFormat?.configurationBox else {
                        return
                    }
                    var buffer = Data([FLVFrameType.key.rawValue << 4 | FLVVideoCodec.avc.rawValue, FLVAVCPacketType.seq.rawValue, 0, 0, 0])
                    buffer.append(configurationBox)
                    doOutput(
                        oldValue == nil ? .zero : .one,
                        chunkStreamId: FLVTagType.video.streamId,
                        message: RTMPVideoMessage(streamId: 0, timestamp: 0, payload: buffer)
                    )
                case .hevc?:
                    guard let configurationBox = videoFormat?.configurationBox else {
                        return
                    }
                    var buffer = Data([0b10000000 | FLVFrameType.key.rawValue << 4 | FLVVideoPacketType.sequenceStart.rawValue, 0x68, 0x76, 0x63, 0x31])
                    buffer.append(configurationBox)
                    doOutput(
                        oldValue == nil ? .zero : .one,
                        chunkStreamId: FLVTagType.video.streamId,
                        message: RTMPVideoMessage(streamId: 0, timestamp: 0, payload: buffer)
                    )
                default:
                    break
                }
            case .playing:
                dispatch(.rtmpStatus, bubbles: false, data: Self.Code.videoDimensionChange.data(""))
            default:
                break
            }
        }
    }

    /// Creates a new stream.
    public init(connection: RTMPConnection, fcPublishName: String? = nil) {
        self.connection = connection
        self.fcPublishName = fcPublishName
        connection.addStream(self)
        addEventListener(.rtmpStatus, selector: #selector(on(status:)), observer: self)
        connection.addEventListener(.rtmpStatus, selector: #selector(on(status:)), observer: self)
        if connection.connected {
            connection.createStream(self)
        }
    }

    deinit {
        removeEventListener(.rtmpStatus, selector: #selector(on(status:)), observer: self)
        connection?.removeEventListener(.rtmpStatus, selector: #selector(on(status:)), observer: self)
    }

    /// Plays a live stream from RTMPServer.
    public func play(_ arguments: Any?...) {
        guard let name = arguments.first as? String else {
            switch readyState {
            case .play, .playing:
                info.resourceName = nil
                close()
            default:
                break
            }
            return
        }

        info.resourceName = name
        let message = RTMPCommandMessage(
            streamId: id,
            transactionId: 0,
            objectEncoding: objectEncoding,
            commandName: "play",
            commandObject: nil,
            arguments: arguments
        )

        switch readyState {
        case .initialized:
            messages.append(message)
        default:
            readyState = .play
            connection?.doOutput(chunk: RTMPChunk(message: message))
        }
    }

    /// Seeks the keyframe.
    public func seek(_ offset: Double) {
        guard self.readyState == .playing else {
            return
        }
        connection?.doOutput(chunk: RTMPChunk(message: RTMPCommandMessage(
            streamId: self.id,
            transactionId: 0,
            objectEncoding: objectEncoding,
            commandName: "seek",
            commandObject: nil,
            arguments: [offset]
        )))
    }

    /// Sends streaming audio, vidoe and data message from client.
    public func publish(_ name: String?, type: RTMPStream.HowToPublish = .live) {
        guard let name else {
            switch readyState {
            case .publish, .publishing:
                close()
            default:
                break
            }
            return
        }

        if info.resourceName == name && readyState == .publishing {
            howToPublish = type
            return
        }

        info.resourceName = name
        howToPublish = type

        let message = RTMPCommandMessage(
            streamId: self.id,
            transactionId: 0,
            objectEncoding: objectEncoding,
            commandName: "publish",
            commandObject: nil,
            arguments: [name, type.rawValue]
        )

        switch readyState {
        case .initialized:
            messages.append(message)
        default:
            readyState = .publish
            connection?.doOutput(chunk: RTMPChunk(message: message))
        }
    }

    /// Stops playing or publishing and makes available other uses.
    public func close() {
        guard let connection, IOStream.ReadyState.open.rawValue < readyState.rawValue else {
            return
        }
        readyState = .open
        if let fcPublishName {
            connection.call("FCUnpublish", responder: nil, arguments: fcPublishName)
        }
        connection.doOutput(chunk: RTMPChunk(
                                type: .zero,
                                streamId: RTMPChunk.StreamID.command.rawValue,
                                message: RTMPCommandMessage(
                                    streamId: 0,
                                    transactionId: 0,
                                    objectEncoding: objectEncoding,
                                    commandName: "closeStream",
                                    commandObject: nil,
                                    arguments: [id]
                                )))
    }

    /// Sends a message on a published stream to all subscribing clients.
    ///
    /// ```
    /// // To add a metadata to a live stream sent to an RTMP Service.
    /// stream.send("@setDataFrame", "onMetaData", metaData)
    /// // To clear a metadata that has already been set in the stream.
    /// stream.send("@clearDataFrame", "onMetaData");
    /// ```
    ///
    /// - Parameters:
    ///   - handlerName: The message to send.
    ///   - arguemnts: Optional arguments.
    ///   - isResetTimestamp: A workaround option for sending timestamps as 0 in some services.
    public func send(handlerName: String, arguments: Any?..., isResetTimestamp: Bool = false) {
        guard readyState == .publishing else {
            return
        }
        if isResetTimestamp {
            dataTimestamps[handlerName] = nil
        }
        let dataWasSent = dataTimestamps[handlerName] == nil ? false : true
        let timestmap: UInt32 = dataWasSent ? UInt32((dataTimestamps[handlerName]?.timeIntervalSinceNow ?? 0) * -1000) : UInt32(startedAt.timeIntervalSinceNow * -1000)
        doOutput(
            dataWasSent ? RTMPChunkType.one : RTMPChunkType.zero,
            chunkStreamId: RTMPChunk.StreamID.data.rawValue,
            message: RTMPDataMessage(
                streamId: id,
                objectEncoding: objectEncoding,
                timestamp: timestmap,
                handlerName: handlerName,
                arguments: arguments
            )
        )
        dataTimestamps[handlerName] = .init()
    }

    func doOutput(_ type: RTMPChunkType, chunkStreamId: UInt16, message: RTMPMessage) {
        message.streamId = id
        let length = connection?.doOutput(chunk: .init(
            type: type,
            streamId: chunkStreamId,
            message: message
        )) ?? 0
        info.byteCount.mutate { $0 += Int64(length) }
    }

    func append(_ message: RTMPAudioMessage, type: RTMPChunkType) {
        let payload = message.payload
        let codec = message.codec
        info.byteCount.mutate { $0 += Int64(payload.count) }
        audioTimestamp.update(message, chunkType: type)
        guard message.codec.isSupported else {
            return
        }
        switch payload[1] {
        case FLVAACPacketType.seq.rawValue:
            let config = AudioSpecificConfig(bytes: [UInt8](payload[codec.headerSize..<payload.count]))
            audioFormat = config?.makeAudioFormat()
        case FLVAACPacketType.raw.rawValue:
            if audioFormat == nil {
                audioFormat = message.makeAudioFormat()
            }
            payload.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> Void in
                guard let baseAddress = buffer.baseAddress, let audioBuffer else {
                    return
                }
                let byteCount = payload.count - codec.headerSize
                audioBuffer.packetDescriptions?.pointee = AudioStreamPacketDescription(mStartOffset: 0, mVariableFramesInPacket: 0, mDataByteSize: UInt32(byteCount))
                audioBuffer.packetCount = 1
                audioBuffer.byteLength = UInt32(byteCount)
                audioBuffer.data.copyMemory(from: baseAddress.advanced(by: codec.headerSize), byteCount: byteCount)
                stream.append(audioBuffer, when: audioTimestamp.value)
            }
        default:
            break
        }
    }

    func append(_ message: RTMPVideoMessage, type: RTMPChunkType) {
        info.byteCount.mutate { $0 += Int64( message.payload.count) }
        videoTimestamp.update(message, chunkType: type)
        guard FLVTagType.video.headerSize <= message.payload.count && message.isSupported else {
            return
        }
        if message.isExHeader {
            // IsExHeader for Enhancing RTMP, FLV
            switch message.packetType {
            case FLVVideoPacketType.sequenceStart.rawValue:
                videoFormat = message.makeFormatDescription()
            case FLVVideoPacketType.codedFrames.rawValue:
                if let sampleBuffer = message.makeSampleBuffer(videoTimestamp.value, formatDesciption: videoFormat) {
                    stream.append(sampleBuffer)
                }
            case FLVVideoPacketType.codedFramesX.rawValue:
                if let sampleBuffer = message.makeSampleBuffer(videoTimestamp.value, formatDesciption: videoFormat) {
                    stream.append(sampleBuffer)
                }
            default:
                break
            }
        } else {
            switch message.packetType {
            case FLVAVCPacketType.seq.rawValue:
                videoFormat = message.makeFormatDescription()
            case FLVAVCPacketType.nal.rawValue:
                if let sampleBuffer = message.makeSampleBuffer(videoTimestamp.value, formatDesciption: videoFormat) {
                    stream.append(sampleBuffer)
                }
            default:
                break
            }
        }
    }

    func append(_ audioBuffer: AVAudioBuffer, when: AVAudioTime) {
        guard let audioBuffer = audioBuffer as? AVAudioCompressedBuffer else {
            return
        }
        let timedelta = audioTimestamp.update(when)
        var buffer = Data([Self.aac, FLVAACPacketType.raw.rawValue])
        buffer.append(audioBuffer.data.assumingMemoryBound(to: UInt8.self), count: Int(audioBuffer.byteLength))
        doOutput(
            .one,
            chunkStreamId: FLVTagType.audio.streamId,
            message: RTMPAudioMessage(streamId: 0, timestamp: timedelta, payload: buffer)
        )
    }

    func append(_ sampleBuffer: CMSampleBuffer) {
        guard let data = try? sampleBuffer.dataBuffer?.dataBytes() else {
            return
        }
        let keyframe = !sampleBuffer.isNotSync
        let decodeTimeStamp = sampleBuffer.decodeTimeStamp.isValid ? sampleBuffer.decodeTimeStamp : sampleBuffer.presentationTimeStamp
        let compositionTime = videoTimestamp.getCompositionTime(sampleBuffer)
        let timedelta = videoTimestamp.update(decodeTimeStamp)
        frameCount += 1
        videoFormat = sampleBuffer.formatDescription
        switch sampleBuffer.formatDescription?.mediaSubType {
        case .h264?:
            var buffer = Data([((keyframe ? FLVFrameType.key.rawValue : FLVFrameType.inter.rawValue) << 4) | FLVVideoCodec.avc.rawValue, FLVAVCPacketType.nal.rawValue])
            buffer.append(contentsOf: compositionTime.bigEndian.data[1..<4])
            buffer.append(data)
            doOutput(
                .one,
                chunkStreamId: FLVTagType.video.streamId,
                message: RTMPVideoMessage(streamId: 0, timestamp: timedelta, payload: buffer)
            )
        case .hevc?:
            var buffer = Data([0b10000000 | ((keyframe ? FLVFrameType.key.rawValue : FLVFrameType.inter.rawValue) << 4) | FLVVideoPacketType.codedFrames.rawValue, 0x68, 0x76, 0x63, 0x31])
            buffer.append(contentsOf: compositionTime.bigEndian.data[1..<4])
            buffer.append(data)
            doOutput(
                .one,
                chunkStreamId: FLVTagType.video.streamId,
                message: RTMPVideoMessage(streamId: 0, timestamp: timedelta, payload: buffer)
            )
        default:
            break
        }
    }

    func on(timer: Timer) {
        currentFPS = frameCount
        frameCount = 0
        info.on(timer: timer)
    }

    func dispatch(_ message: RTMPDataMessage) {
        info.byteCount.mutate { $0 += Int64(message.payload.count) }
        switch message.handlerName {
        case "onMetaData":
            metadata = message.arguments[0] as? [String: Any?] ?? [:]
        case "|RtmpSampleAccess":
            audioSampleAccess = message.arguments[0] as? Bool ?? true
            videoSampleAccess = message.arguments[1] as? Bool ?? true
        default:
            break
        }
    }

    /// Creates flv metadata for a stream.
    private func makeMetaData() -> ASObject {
        var metadata: [String: Any] = [
            "duration": 0
        ]
        if stream.videoInputFormat != nil {
            metadata["width"] = stream.videoSettings.videoSize.width
            metadata["height"] = stream.videoSettings.videoSize.height
            #if os(iOS) || os(macOS) || os(tvOS)
            // metadata["framerate"] = stream.frameRate
            #endif
            switch stream.videoSettings.format {
            case .h264:
                metadata["videocodecid"] = FLVVideoCodec.avc.rawValue
            case .hevc:
                metadata["videocodecid"] = FLVVideoFourCC.hevc.rawValue
            }
            metadata["videodatarate"] = stream.videoSettings.bitRate / 1000
        }
        if stream.audioInputFormat != nil {
            metadata["audiocodecid"] = FLVAudioCodec.aac.rawValue
            metadata["audiodatarate"] = stream.audioSettings.bitRate / 1000
            /*
             if let outputFormat = mixer.audioIO.outputFormat {
             metadata["audiosamplerate"] = outputFormat.sampleRate
             }
             */
        }
        return metadata
    }

    @objc
    private func on(status: Notification) {
        let e = Event.from(status)
        guard let connection, let data = e.data as? ASObject, let code = data["code"] as? String else {
            return
        }
        switch code {
        case RTMPConnection.Code.connectSuccess.rawValue:
            readyState = .initialized
            connection.createStream(self)
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

extension RTMPStream: IOStreamConvertible {
    // MARK: IOStreamConvertible
    public var video: AsyncStream<CMSampleBuffer> {
        get async {
            let (stream, continuation) = AsyncStream<CMSampleBuffer>.makeStream()
            continuations.append(continuation)
            return stream
        }
    }

    public var audioSettings: AudioCodecSettings {
        get async {
            stream.audioSettings
        }
    }

    public var videoSettings: VideoCodecSettings {
        get async {
            stream.videoSettings
        }
    }

    public func append(_ sampleBuffer: CMSampleBuffer) async {
        stream.append(sampleBuffer)
        continuations.forEach { $0.yield(sampleBuffer) }
    }

    public func append(_ audioBuffer: AVAudioBuffer, when: AVAudioTime) async {
        stream.append(audioBuffer, when: when)
    }

    public func setAudioSettings(_ audioSettings: AudioCodecSettings) async {
        stream.audioSettings = audioSettings
    }

    public func setVideoSettings(_ videoSettings: VideoCodecSettings) async {
        stream.videoSettings = videoSettings
    }
}

extension RTMPStream: EventDispatcherConvertible {
    // MARK: EventDispatcherConvertible
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
