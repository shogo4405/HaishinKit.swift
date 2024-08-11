import AVFAudio
import AVFoundation

/// An object that provides the interface to control a one-way channel over an RTMPConnection.
public actor RTMPStream {
    // The RTMPStream error domain code.
    public enum Error: Swift.Error {
        case invalidState
        case requestTimedOut
        case requestFailed(response: RTMPResponse)
    }

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

        func status(_ description: String) -> RTMPStatus {
            return .init(code: rawValue, level: level, description: description)
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
    public private(set) var metadata: AMFArray = .init(count: 0)
    /// The RTMPStreamInfo object whose properties contain data.
    public private(set) var info = RTMPStreamInfo()
    /// The object encoding (AMF). Framework supports AMF0 only.
    public private(set) var objectEncoding: RTMPObjectEncoding = RTMPConnection.defaultObjectEncoding
    /// The boolean value that indicates audio samples allow access or not.
    public private(set) var audioSampleAccess = true
    /// The boolean value that indicates video samples allow access or not.
    public private(set) var videoSampleAccess = true
    /// The number of video frames per seconds.
    public private(set) var currentFPS: UInt16 = 0
    /// The ready state of stream.
    public private(set) var readyState: HKStreamReadyState = .idle
    /// The stream of events you receive RTMP status events from a service.
    public var status: AsyncStream<RTMPStatus> {
        let (stream, continutation) = AsyncStream<RTMPStatus>.makeStream()
        statusContinuation = continutation
        return stream
    }
    /// The stream's name used for FMLE-compatible sequences.
    public private(set) var fcPublishName: String?

    private var isPaused = false
    private var startedAt = Date() {
        didSet {
            dataTimestamps.removeAll()
        }
    }
    private var observers: [any HKStreamObserver] = []
    private var frameCount: UInt16 = 0
    private var audioBuffer: AVAudioCompressedBuffer?
    private var howToPublish: RTMPStream.HowToPublish = .live
    private var continuation: CheckedContinuation<RTMPResponse, any Swift.Error>? {
        didSet {
            if continuation == nil {
                expectedResponse = nil
            }
        }
    }
    private var dataTimestamps: [String: Date] = .init()
    private var audioTimestamp: RTMPTimestamp<AVAudioTime> = .init()
    private var videoTimestamp: RTMPTimestamp<CMTime> = .init()
    private var requestTimeout: UInt64 = RTMPConnection.defaultRequestTimeout
    private var expectedResponse: Code?
    private var statusContinuation: AsyncStream<RTMPStatus>.Continuation?
    private(set) var id: UInt32 = RTMPStream.defaultID
    private lazy var stream = MediaCodec()
    private lazy var mediaLink = MediaLink()
    private weak var connection: RTMPConnection?
    private weak var audioPlayerNode: AudioPlayerNode?
    private var bitrateStorategy: (any HKStreamBitRateStrategy)?

    private var audioFormat: AVAudioFormat? {
        didSet {
            switch readyState {
            case .publishing:
                guard let message = RTMPAudioMessage(streamId: id, timestamp: 0, formatDescription: audioFormat?.formatDescription) else {
                    return
                }
                doOutput(oldValue == nil ? .zero : .one, chunkStreamId: .audio, message: message)
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
                guard let message = RTMPVideoMessage(streamId: id, timestamp: 0, formatDescription: videoFormat) else {
                    return
                }
                doOutput(oldValue == nil ? .zero : .one, chunkStreamId: .video, message: message)
            case .playing:
                break
            default:
                break
            }
        }
    }

    /// Creates a new stream.
    public init(connection: RTMPConnection, fcPublishName: String? = nil) {
        self.connection = connection
        self.fcPublishName = fcPublishName
        Task {
            await connection.addStream(self)
            if await connection.connected {
                await createStream()
            }
        }
    }

    /// Plays a live stream from a server.
    public func play(_ arguments: (any Sendable)?...) async throws -> RTMPResponse {
        guard let name = arguments.first as? String else {
            switch readyState {
            case .playing:
                info.resourceName = nil
                return try await close()
            default:
                throw Error.invalidState
            }
        }
        do {
            let response = try await withCheckedThrowingContinuation { continuation in
                readyState = .play
                expectedResponse = Code.playStart
                self.continuation = continuation
                Task {
                    try? await Task.sleep(nanoseconds: requestTimeout * 1_000_000)
                    self.continuation.map {
                        $0.resume(throwing: Error.requestTimedOut)
                    }
                    self.continuation = nil
                }
                stream.audioSettings.format = .pcm
                stream.startRunning()
                Task {
                    await mediaLink.startRunning()
                    while stream.isRunning {
                        do {
                            for try await video in stream.video where stream.isRunning {
                                await mediaLink.enqueue(video)
                            }
                        } catch {
                            logger.error(error)
                        }
                    }
                }
                Task {
                    guard let audioPlayerNode else {
                        return
                    }
                    await audioPlayerNode.startRunning()
                    for await audio in stream.audio where stream.isRunning {
                        await audioPlayerNode.enqueue(audio.0, when: audio.1)
                    }
                }
                Task {
                    for await video in await mediaLink.dequeue where stream.isRunning {
                        observers.forEach { $0.stream(self, didOutput: video) }
                    }
                }
                doOutput(.zero, chunkStreamId: .command, message: RTMPCommandMessage(
                    streamId: id,
                    transactionId: 0,
                    objectEncoding: objectEncoding,
                    commandName: "play",
                    commandObject: nil,
                    arguments: arguments
                ))
            }
            startedAt = .init()
            readyState = .playing
            info.resourceName = name
            return response
        } catch {
            await mediaLink.stopRunning()
            await audioPlayerNode?.stopRunning()
            stream.stopRunning()
            readyState = .idle
            throw error
        }
    }

    /// Seeks the keyframe.
    public func seek(_ offset: Double) async throws {
        guard readyState == .playing else {
            throw Error.invalidState
        }
        doOutput(.zero, chunkStreamId: .command, message: RTMPCommandMessage(
            streamId: id,
            transactionId: 0,
            objectEncoding: objectEncoding,
            commandName: "seek",
            commandObject: nil,
            arguments: [offset]
        ))
    }

    /// Sends streaming audio, vidoe and data message from client.
    public func publish(_ name: String?, type: RTMPStream.HowToPublish = .live) async throws -> RTMPResponse {
        guard let name else {
            switch readyState {
            case .publishing:
                return try await close()
            default:
                throw Error.invalidState
            }
        }
        do {
            let response = try await withCheckedThrowingContinuation { continuation in
                readyState = .publish
                expectedResponse = Code.publishStart
                self.continuation = continuation
                Task {
                    try? await Task.sleep(nanoseconds: requestTimeout * 1_000_000)
                    self.continuation.map {
                        $0.resume(throwing: Error.requestTimedOut)
                    }
                    self.continuation = nil
                }
                doOutput(.zero, chunkStreamId: .command, message: RTMPCommandMessage(
                    streamId: id,
                    transactionId: 0,
                    objectEncoding: objectEncoding,
                    commandName: "publish",
                    commandObject: nil,
                    arguments: [name, type.rawValue]
                ))
            }
            info.resourceName = name
            howToPublish = type
            stream.startRunning()
            startedAt = .init()
            metadata = makeMetadata()
            try? send("@setDataFrame", arguments: "onMetaData", metadata)
            Task {
                for await audio in stream.audio where stream.isRunning {
                    append(audio.0, when: audio.1)
                }
            }
            Task {
                for try await video in stream.video where stream.isRunning {
                    append(video)
                }
            }
            readyState = .publishing
            return response
        } catch {
            readyState = .idle
            throw error
        }
    }

    /// Stops playing or publishing and makes available other uses.
    public func close() async throws -> RTMPResponse {
        guard readyState == .playing || readyState == .publishing else {
            throw Error.invalidState
        }
        stream.stopRunning()
        await mediaLink.stopRunning()
        await audioPlayerNode?.stopRunning()
        return try await withCheckedThrowingContinuation { continutation in
            self.continuation = continutation
            switch readyState {
            case .playing:
                expectedResponse = Code.playStop
            case .publishing:
                expectedResponse = Code.unpublishSuccess
            default:
                break
            }
            Task {
                try? await Task.sleep(nanoseconds: requestTimeout * 1_000_000)
                self.continuation.map {
                    $0.resume(throwing: Error.requestTimedOut)
                }
                self.continuation = nil
            }
            doOutput(.zero, chunkStreamId: .command, message: RTMPCommandMessage(
                streamId: id,
                transactionId: 0,
                objectEncoding: objectEncoding,
                commandName: "closeStream",
                commandObject: nil,
                arguments: []
            ))
            readyState = .idle
        }
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
    public func send(_ handlerName: String, arguments: (any Sendable)?..., isResetTimestamp: Bool = false) throws {
        guard readyState == .publishing else {
            throw Error.invalidState
        }
        if isResetTimestamp {
            dataTimestamps[handlerName] = nil
        }
        let dataWasSent = dataTimestamps[handlerName] == nil ? false : true
        let timestmap: UInt32 = dataWasSent ? UInt32((dataTimestamps[handlerName]?.timeIntervalSinceNow ?? 0) * -1000) : UInt32(startedAt.timeIntervalSinceNow * -1000)
        doOutput(
            dataWasSent ? RTMPChunkType.one : RTMPChunkType.zero,
            chunkStreamId: .data,
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

    /// Incoming audio plays on a stream or not.
    public func receiveAudio(_ receiveAudio: Bool) async throws {
        guard readyState == .playing else {
            throw Error.invalidState
        }
        doOutput(.zero, chunkStreamId: .command, message: RTMPCommandMessage(
            streamId: id,
            transactionId: 0,
            objectEncoding: objectEncoding,
            commandName: "receiveAudio",
            commandObject: nil,
            arguments: [receiveAudio]
        ))
    }

    /// Incoming video plays on a stream or not.
    public func receiveVideo(_ receiveVideo: Bool) async throws {
        guard readyState == .playing else {
            throw Error.invalidState
        }
        doOutput(.zero, chunkStreamId: .command, message: RTMPCommandMessage(
            streamId: id,
            transactionId: 0,
            objectEncoding: objectEncoding,
            commandName: "receiveVideo",
            commandObject: nil,
            arguments: [receiveVideo]
        ))
    }

    /// Pauses playback a  stream or not.
    public func pause(_ paused: Bool) async throws -> RTMPResponse {
        guard readyState == .playing else {
            throw Error.invalidState
        }
        let response = try await withCheckedThrowingContinuation { continuation in
            expectedResponse = isPaused ? Code.pauseNotify : Code.unpauseNotify
            self.continuation = continuation
            Task {
                try? await Task.sleep(nanoseconds: requestTimeout * 1_000_000)
                self.continuation.map {
                    $0.resume(throwing: Error.requestTimedOut)
                }
                self.continuation = nil
            }
            doOutput(.zero, chunkStreamId: .command, message: RTMPCommandMessage(
                streamId: id,
                transactionId: 0,
                objectEncoding: objectEncoding,
                commandName: "pause",
                commandObject: nil,
                arguments: [paused, floor(startedAt.timeIntervalSinceNow * -1000)]
            ))
        }
        isPaused = paused
        return response
    }

    /// Pauses or resumes playback of a stream.
    public func togglePause() async throws -> RTMPResponse {
        try await pause(!isPaused)
    }

    func doOutput(_ type: RTMPChunkType, chunkStreamId: RTMPChunkStreamId, message: some RTMPMessage) {
        Task {
            let length = await connection?.doOutput(type, chunkStreamId: chunkStreamId, message: message) ?? 0
            info.byteCount += length
        }
    }

    func dispatch(_ message: some RTMPMessage, type: RTMPChunkType) {
        info.byteCount += message.payload.count
        switch message {
        case let message as RTMPCommandMessage:
            let response = RTMPResponse(message)
            switch message.commandName {
            case "onStatus":
                switch response.status?.level {
                case "status":
                    if let code = response.status?.code, expectedResponse?.rawValue == code {
                        continuation?.resume(returning: response)
                        continuation = nil
                    }
                default:
                    continuation?.resume(throwing: Error.requestFailed(response: response))
                    continuation = nil
                }
                _ = response.status.map {
                    statusContinuation?.yield($0)
                }
            default:
                continuation?.resume(throwing: Error.requestFailed(response: response))
                connection = nil
            }
        case let message as RTMPAudioMessage:
            append(message, type: type)
        case let message as RTMPVideoMessage:
            append(message, type: type)
        case let message as RTMPDataMessage:
            switch message.handlerName {
            case "onMetaData":
                metadata = message.arguments[0] as? AMFArray ?? .init(count: 0)
            case "|RtmpSampleAccess":
                audioSampleAccess = message.arguments[0] as? Bool ?? true
                videoSampleAccess = message.arguments[1] as? Bool ?? true
            default:
                break
            }
        case let message as RTMPUserControlMessage:
            switch message.event {
            case .bufferEmpty:
                statusContinuation?.yield(Code.bufferEmpty.status(""))
            case .bufferFull:
                statusContinuation?.yield(Code.bufferFull.status(""))
            default:
                break
            }
        default:
            break
        }
    }

    func createStream() async {
        if let fcPublishName {
            // FMLE-compatible sequences
            async let _ = connection?.call("releaseStream", arguments: fcPublishName)
            async let _ = connection?.call("FCPublish", arguments: fcPublishName)
        }
        do {
            let response = try await connection?.call("createStream")
            guard let first = response?.arguments.first as? Double else {
                return
            }
            id = UInt32(first)
            readyState = .idle
        } catch {
            logger.error(error)
        }
    }

    func deleteStream() async {
        guard let fcPublishName, readyState == .publishing else {
            return
        }
        stream.stopRunning()
        await mediaLink.stopRunning()
        await audioPlayerNode?.stopRunning()
        async let _ = try? connection?.call("FCUnpublish", arguments: fcPublishName)
        async let _ = try? connection?.call("deleteStream", arguments: id)
    }

    private func append(_ message: RTMPAudioMessage, type: RTMPChunkType) {
        let payload = message.payload
        let codec = message.codec
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
            if let audioBuffer {
                message.copyMemory(audioBuffer)
                stream.append(audioBuffer, when: audioTimestamp.value)
            }
        default:
            break
        }
    }

    private func append(_ message: RTMPVideoMessage, type: RTMPChunkType) {
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

    /// Creates flv metadata for a stream.
    private func makeMetadata() -> AMFArray {
        var metadata: AMFObject = [
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
        if let audioFormat = stream.audioInputFormat {
            metadata["audiocodecid"] = FLVAudioCodec.aac.rawValue
            metadata["audiodatarate"] = stream.audioSettings.bitRate / 1000
            metadata["audiosamplerate"] = audioFormat.sampleRate
        }
        return AMFArray(metadata)
    }
}

extension RTMPStream: HKStream {
    // MARK: IOStreamConvertible
    public var audioSettings: AudioCodecSettings {
        stream.audioSettings
    }

    public func setAudioSettings(_ audioSettings: AudioCodecSettings) {
        stream.audioSettings = audioSettings
    }

    public var videoSettings: VideoCodecSettings {
        stream.videoSettings
    }

    public func setVideoSettings(_ videoSettings: VideoCodecSettings) {
        stream.videoSettings = videoSettings
    }

    public func append(_ sampleBuffer: CMSampleBuffer) {
        if sampleBuffer.formatDescription?.isCompressed == true {
            let decodeTimeStamp = sampleBuffer.decodeTimeStamp.isValid ? sampleBuffer.decodeTimeStamp : sampleBuffer.presentationTimeStamp
            let compositionTime = videoTimestamp.getCompositionTime(sampleBuffer)
            let timedelta = videoTimestamp.update(decodeTimeStamp)
            frameCount += 1
            videoFormat = sampleBuffer.formatDescription
            guard let message = RTMPVideoMessage(streamId: id, timestamp: timedelta, compositionTime: compositionTime, sampleBuffer: sampleBuffer) else {
                return
            }
            doOutput(.one, chunkStreamId: .video, message: message)
        } else {
            stream.append(sampleBuffer)
            observers.forEach { $0.stream(self, didOutput: sampleBuffer) }
        }
    }

    public func append(_ audioBuffer: AVAudioBuffer, when: AVAudioTime) {
        switch audioBuffer {
        case let audioBuffer as AVAudioCompressedBuffer:
            let timedelta = audioTimestamp.update(when)
            guard let message = RTMPAudioMessage(streamId: id, timestamp: timedelta, audioBuffer: audioBuffer) else {
                return
            }
            doOutput(.one, chunkStreamId: .audio, message: message)
        default:
            stream.append(audioBuffer, when: when)
        }
    }

    public func attachAudioPlayer(_ audioPlayer: AudioPlayer?) async {
        audioPlayerNode = await audioPlayer?.makePlayerNode()
    }

    public func addObserver(_ observer: some HKStreamObserver) {
        guard !observers.contains(where: { $0 === observer }) else {
            return
        }
        observers.append(observer)
    }

    public func removeObserver(_ observer: some HKStreamObserver) {
        if let index = observers.firstIndex(where: { $0 === observer }) {
            observers.remove(at: index)
        }
    }

    public func setBitrateStorategy(_ bitrateStorategy: (some HKStreamBitRateStrategy)?) {
        self.bitrateStorategy = bitrateStorategy
    }

    public func dispatch(_ event: NetworkMonitorEvent) {
        bitrateStorategy?.adjustBitrate(event, stream: self)
        currentFPS = frameCount
        frameCount = 0
        info.update()
    }
}
