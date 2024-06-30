import AVFoundation
import Foundation

/// The RTMPResponder class provides to use handle RTMPConnection's callback.
open class RTMPResponder {
    /// A Handler represents RTMPResponder's callback function.
    public typealias Handler = (_ data: [Any?]) -> Void

    private var result: Handler
    private var status: Handler?

    /// Creates a new RTMPResponder object.
    public init(result: @escaping Handler, status: Handler? = nil) {
        self.result = result
        self.status = status
    }

    final func on(result: [Any?]) {
        self.result(result)
    }

    final func on(status: [Any?]) {
        self.status?(status)
        self.status = nil
    }
}

/// The interface a RTMPConnectionDelegate uses to inform its delegate.
public protocol RTMPConnectionDelegate: AnyObject {
    /// Tells the receiver to publish insufficient bandwidth occured.
    func connection(_ connection: RTMPConnection, publishInsufficientBWOccured stream: RTMPStream)
    /// Tells the receiver to publish sufficient bandwidth occured.
    func connection(_ connection: RTMPConnection, publishSufficientBWOccured stream: RTMPStream)
    /// Tells the receiver to update statistics.
    func connection(_ connection: RTMPConnection, updateStats stream: RTMPStream)
}

// MARK: -
/// The RTMPConneciton class create a two-way RTMP connection.
public actor RTMPConnection {
    enum ReadyState: UInt8 {
        case uninitialized = 0
        case versionSent = 1
        case ackSent = 2
        case handshakeDone = 3
        case closing = 4
        case closed = 5
    }

    /// The default time to wait for TCP/IP Handshake done.
    public static let defaultTimeout: Int = 15 // sec
    /// The default network's window size for RTMPConnection.
    public static let defaultWindowSizeS: Int64 = 250000
    /// The supported protocols are rtmp, rtmps, rtmpt and rtmps.
    public static let supportedProtocols: Set<String> = ["rtmp", "rtmps", "rtmpt", "rtmpts"]
    /// The supported fourCcList are hvc1.
    public static let supportedFourCcList = ["hvc1"]
    /// The default RTMP port is 1935.
    public static let defaultPort: Int = 1935
    /// The default RTMPS port is 443.
    public static let defaultSecurePort: Int = 443
    /// The default flashVer is FMLE/3.0 (compatible; FMSc/1.0).
    public static let defaultFlashVer: String = "FMLE/3.0 (compatible; FMSc/1.0)"
    /// The default chunk size for RTMPConnection.
    public static let defaultChunkSizeS: Int = 1024 * 8
    /// The default capabilities for RTMPConneciton.
    public static let defaultCapabilities: Int = 239
    /// The default object encoding for RTMPConnection class.
    public static let defaultObjectEncoding: RTMPObjectEncoding = .amf0

    /**
     - NetStatusEvent#info.code for NetConnection
     - see: https://help.adobe.com/en_US/air/reference/html/flash/events/NetStatusEvent.html#NET_STATUS
     */
    public enum Code: String {
        case callBadVersion       = "NetConnection.Call.BadVersion"
        case callFailed           = "NetConnection.Call.Failed"
        case callProhibited       = "NetConnection.Call.Prohibited"
        case connectAppshutdown   = "NetConnection.Connect.AppShutdown"
        case connectClosed        = "NetConnection.Connect.Closed"
        case connectFailed        = "NetConnection.Connect.Failed"
        case connectIdleTimeOut   = "NetConnection.Connect.IdleTimeOut"
        case connectInvalidApp    = "NetConnection.Connect.InvalidApp"
        case connectNetworkChange = "NetConnection.Connect.NetworkChange"
        case connectRejected      = "NetConnection.Connect.Rejected"
        case connectSuccess       = "NetConnection.Connect.Success"

        public var level: String {
            switch self {
            case .callBadVersion:
                return "error"
            case .callFailed:
                return "error"
            case .callProhibited:
                return "error"
            case .connectAppshutdown:
                return "error"
            case .connectClosed:
                return "status"
            case .connectFailed:
                return "error"
            case .connectIdleTimeOut:
                return "status"
            case .connectInvalidApp:
                return "error"
            case .connectNetworkChange:
                return "status"
            case .connectRejected:
                return "error"
            case .connectSuccess:
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

    enum SupportVideo: UInt16 {
        case unused = 0x0001
        case jpeg = 0x0002
        case sorenson = 0x0004
        case homebrew = 0x0008
        case vp6 = 0x0010
        case vp6Alpha = 0x0020
        case homebrewv = 0x0040
        case h264 = 0x0080
        case all = 0x00FF
    }

    enum SupportSound: UInt16 {
        case none = 0x0001
        case adpcm = 0x0002
        case mp3 = 0x0004
        case intel = 0x0008
        case unused = 0x0010
        case nelly8 = 0x0020
        case nelly = 0x0040
        case g711A = 0x0080
        case g711U = 0x0100
        case nelly16 = 0x0200
        case aac = 0x0400
        case speex = 0x0800
        case all = 0x0FFF
    }

    enum VideoFunction: UInt8 {
        case clientSeek = 1
    }

    private static func makeSanJoseAuthCommand(_ url: URL, description: String) -> String {
        var command: String = url.absoluteString

        guard let index = description.firstIndex(of: "?") else {
            return command
        }

        let query = String(description[description.index(index, offsetBy: 1)...])
        let challenge = String(format: "%08x", UInt32.random(in: 0...UInt32.max))
        let dictionary = URL(string: "http://localhost?" + query)!.dictionaryFromQuery()

        var response = MD5.base64("\(url.user!)\(dictionary["salt"]!)\(url.password!)")
        if let opaque = dictionary["opaque"] {
            command += "&opaque=\(opaque)"
            response += opaque
        } else if let challenge: String = dictionary["challenge"] {
            response += challenge
        }

        response = MD5.base64("\(response)\(challenge)")
        command += "&challenge=\(challenge)&response=\(response)"

        return command
    }

    /// Specifies the URL of .swf.
    public var swfUrl: String?
    /// Specifies the URL of an HTTP referer.
    public var pageUrl: String?
    /// Specifies the time to wait for TCP/IP Handshake done.
    public var timeout: Int = RTMPConnection.defaultTimeout
    /// Specifies the dispatchQos for socket.
    public var qualityOfService: DispatchQoS = .userInitiated
    /// Specifies the name of application.
    public var flashVer: String = RTMPConnection.defaultFlashVer
    /// Specifies theoutgoing RTMPChunkSize.
    public var chunkSize: Int = RTMPConnection.defaultChunkSizeS
    /// Specifies the URI passed to the Self.connect() method.
    public private(set) var uri: URL?
    /// Specifies the instance connected to server(true) or not(false).
    public private(set) var connected = false
    /// Specifies the socket optional parameters.
    public var parameters: Any?
    /// Specifies the object encoding for this RTMPConnection instance.
    public var objectEncoding: RTMPObjectEncoding = RTMPConnection.defaultObjectEncoding
    /// The statistics of total incoming bytes.
    public var totalBytesIn: Int64 = 0
    /// The statistics of total outgoing bytes.
    public var totalBytesOut: Int64 = 0
    /// The statistics of total RTMPStream counts.
    public var totalStreamsCount: Int {
        streams.count
    }
    /// Specifies the delegate of the RTMPConnection.
    public weak var delegate: (any RTMPConnectionDelegate)?
    /// The statistics of outgoing queue bytes per second.
    public private(set) var previousQueueBytesOut: [Int64] = []
    /// The statistics of incoming bytes per second.
    public private(set) var currentBytesInPerSecond: Int32 = 0
    /// The statistics of outgoing bytes per second.
    public private(set) var currentBytesOutPerSecond: Int32 = 0

    var timestamp: TimeInterval {
        socket.timestamp
    }

    var newTransaction: Int {
        currentTransactionId += 1
        return currentTransactionId
    }

    private var socket = RTMPSocket()
    private var streams: [RTMPStream] = []
    private var sequence: Int64 = 0
    private var bandWidth: UInt32 = 0
    private var handshake = RTMPHandshake()
    private var readyState: ReadyState = .uninitialized
    private var chunkSizeC: Int = RTMPChunk.defaultSize
    private var chunkSizeS: Int = RTMPChunk.defaultSize
    private var streamsmap: [UInt16: UInt32] = [:]
    private var operations: [Int: RTMPResponder] = [:]
    private var inputBuffer = Data()
    private var windowSizeC = RTMPConnection.defaultWindowSizeS {
        didSet {
            guard connected else {
                return
            }
            doOutput(chunk: RTMPChunk(
                type: .zero,
                streamId: RTMPChunk.StreamID.control.rawValue,
                message: RTMPWindowAcknowledgementSizeMessage(UInt32(windowSizeC))
            ))
        }
    }
    private var windowSizeS: Int64 = RTMPConnection.defaultWindowSizeS
    private var currentTransactionId: Int = 0
    private lazy var dispatcher: EventDispatcher = {
        return EventDispatcher(target: self)
    }()
    private var messages: [UInt16: RTMPMessage] = [:]
    private var arguments: [Any?] = []
    private var currentChunk: RTMPChunk?
    private var measureInterval: Int = 3
    private var fragmentedChunks: [UInt16: RTMPChunk] = [:]
    private var previousTotalBytesIn: Int64 = 0
    private var previousTotalBytesOut: Int64 = 0

    /// Creates a new connection.
    public init() {
        Task {
            await addEventListener(.rtmpStatus, listener: self)
        }
    }

    deinit {
        streams.removeAll()
        Task {
            await removeEventListener(.rtmpStatus, listener: self)
        }
    }

    /// Calls a command or method on RTMP Server.
    public func call(_ commandName: String, responder: RTMPResponder?, arguments: Any?...) {
        guard connected else {
            return
        }
        let message = RTMPCommandMessage(
            streamId: 0,
            transactionId: newTransaction,
            objectEncoding: objectEncoding,
            commandName: commandName,
            commandObject: nil,
            arguments: arguments
        )
        if responder != nil {
            operations[message.transactionId] = responder
        }
        doOutput(chunk: RTMPChunk(message: message))
    }

    /// Creates a two-way connection to an application on RTMP Server.
    public func connect(_ command: String, arguments: Any?...) {
        guard let uri = URL(string: command), let scheme = uri.scheme, let host = uri.host, !connected && Self.supportedProtocols.contains(scheme) else {
            return
        }
        self.uri = uri
        self.arguments = arguments
        socket = RTMPSocket()
        // socket.timeout = timeout
        socket.qualityOfService = qualityOfService
        let secure = uri.scheme == "rtmps" || uri.scheme == "rtmpts"
        socket.securityLevel = secure ? .negotiatedSSL : .none
        Task {
            do {
                let stream = try await socket.connect(host, port: uri.port ?? (secure ? Self.defaultSecurePort : Self.defaultPort))
                for await data in stream {
                    inputBuffer.append(data)
                    try await self.listen()
                }
                connected = true
            } catch {
                connected = false
            }
        }
    }

    /// Closes the connection from the server.
    public func close() {
        close(isDisconnected: false)
    }

    @discardableResult
    func doOutput(chunk: RTMPChunk) -> Int {
        let chunks: [Data] = chunk.split(chunkSizeS)
        for i in 0..<chunks.count - 1 {
            Task {
                try await socket.send(chunks[i])
            }
        }
        Task {
            try await socket.send(chunks.last!)
        }
        if logger.isEnabledFor(level: .trace) {
            logger.trace(chunk)
        }
        return 0
    }

    func close(isDisconnected: Bool) {
        guard connected || isDisconnected else {
            return
        }
        if !isDisconnected {
            uri = nil
        }
        for stream in streams {
            Task {
                await stream.close()
            }
        }
        socket.close()
    }

    func addStream(_ stream: RTMPStream) {
        streams.append(stream)
    }

    func createStream(_ stream: RTMPStream) async {
        if let fcPublishName = await stream.fcPublishName {
            // FMLE-compatible sequences
            call("releaseStream", responder: nil, arguments: fcPublishName)
            call("FCPublish", responder: nil, arguments: fcPublishName)
        }
        call("createStream", responder: await stream.makeCreateResponder())
    }

    private func listen() async throws {
        switch readyState {
        case .versionSent:
            if inputBuffer.count < RTMPHandshake.sigSize + 1 {
                break
            }
            try await socket.send(handshake.c2packet(inputBuffer))
            inputBuffer.removeSubrange(0...RTMPHandshake.sigSize)
            readyState = .ackSent
            if RTMPHandshake.sigSize <= inputBuffer.count {
                try await listen()
            }
        case .ackSent:
            if inputBuffer.count < RTMPHandshake.sigSize {
                break
            }
            inputBuffer.removeAll()
            let timer = AsyncStream {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            Task {
                for await _ in timer {
                    updateStats()
                }
            }
            readyState = .handshakeDone
        case .handshakeDone, .closing:
            if inputBuffer.isEmpty {
                break
            }
            let bytes: Data = inputBuffer
            read(bytes)
            inputBuffer.removeAll()
        default:
            break
        }
    }

    private func read(_ data: Data) {
        guard let chunk = currentChunk ?? RTMPChunk(data, size: chunkSizeC) else {
            inputBuffer.append(data)
            return
        }

        var position = chunk.data.count
        if (4 <= chunk.data.count) && (chunk.data[1] == 0xFF) && (chunk.data[2] == 0xFF) && (chunk.data[3] == 0xFF) {
            position += 4
        }

        if currentChunk != nil {
            position = chunk.append(data, size: chunkSizeC)
        }
        if chunk.type == .two {
            position = chunk.append(data, message: messages[chunk.streamId])
        }
        if chunk.type == .three && fragmentedChunks[chunk.streamId] == nil {
            position = chunk.append(data, message: messages[chunk.streamId])
        }

        if let message = chunk.message, chunk.ready {
            if logger.isEnabledFor(level: .trace) {
                logger.trace(chunk)
            }
            switch chunk.type {
            case .zero:
                streamsmap[chunk.streamId] = message.streamId
            case .one:
                if let streamId = streamsmap[chunk.streamId] {
                    message.streamId = streamId
                }
            case .two:
                break
            case .three:
                break
            }
            dispatch(message, type: chunk.type)
            currentChunk = nil
            messages[chunk.streamId] = message
            if 0 < position && position < data.count {
                self.read(data.advanced(by: position))
            }
            return
        }

        if chunk.fragmented {
            fragmentedChunks[chunk.streamId] = chunk
            currentChunk = nil
        } else {
            currentChunk = chunk.type == .three ? fragmentedChunks[chunk.streamId] : chunk
            fragmentedChunks.removeValue(forKey: chunk.streamId)
        }

        if 0 < position && position < data.count {
            self.read(data.advanced(by: position))
        }
    }

    private func makeConnectionChunk() -> RTMPChunk? {
        guard let uri else {
            return nil
        }

        var app = uri.path.isEmpty ? "" : String(uri.path[uri.path.index(uri.path.startIndex, offsetBy: 1)...])
        if let query = uri.query {
            app += "?" + query
        }

        let message = RTMPCommandMessage(
            streamId: 0,
            transactionId: newTransaction,
            // "connect" must be a objectEncoding = 0
            objectEncoding: .amf0,
            commandName: "connect",
            commandObject: [
                "app": app,
                "flashVer": flashVer,
                "swfUrl": swfUrl,
                "tcUrl": uri.absoluteWithoutAuthenticationString,
                "fpad": false,
                "capabilities": Self.defaultCapabilities,
                "audioCodecs": SupportSound.aac.rawValue,
                "videoCodecs": SupportVideo.h264.rawValue,
                "videoFunction": VideoFunction.clientSeek.rawValue,
                "pageUrl": pageUrl,
                "fourCcList": Self.supportedFourCcList,
                "objectEncoding": objectEncoding.rawValue
            ],
            arguments: arguments
        )

        return RTMPChunk(message: message)
    }

    private func updateStats() {
        let totalBytesIn = self.totalBytesIn
        let totalBytesOut = self.totalBytesOut
        let queueBytesOut: Int64 = 0
        currentBytesInPerSecond = Int32(totalBytesIn - previousTotalBytesIn)
        currentBytesOutPerSecond = Int32(totalBytesOut - previousTotalBytesOut)
        previousTotalBytesIn = totalBytesIn
        previousTotalBytesOut = totalBytesOut
        previousQueueBytesOut.append(queueBytesOut)
        for stream in streams {
            // stream.on(timer: timer)
        }
        if measureInterval <= previousQueueBytesOut.count {
            var total = 0
            for i in 0..<previousQueueBytesOut.count - 1 where previousQueueBytesOut[i] < previousQueueBytesOut[i + 1] {
                total += 1
            }
            if total == measureInterval - 1 {
                for stream in streams {
                    /*
                     stream.bitrateStrategy.insufficientBWOccured(IOStreamBitRateStats(
                     currentQueueBytesOut: queueBytesOut,
                     currentBytesInPerSecond: currentBytesInPerSecond,
                     currentBytesOutPerSecond: currentBytesOutPerSecond
                     ))
                     */
                    delegate?.connection(self, publishInsufficientBWOccured: stream)
                }
            } else if total == 0 {
                for stream in streams {
                    /*
                     stream.bitrateStrategy.sufficientBWOccured(IOStreamBitRateStats(
                     currentQueueBytesOut: queueBytesOut,
                     currentBytesInPerSecond: currentBytesInPerSecond,
                     currentBytesOutPerSecond: currentBytesOutPerSecond
                     ))
                     */
                    delegate?.connection(self, publishSufficientBWOccured: stream)
                }
            }
            previousQueueBytesOut.removeFirst()
        }
        for stream in streams {
            delegate?.connection(self, updateStats: stream)
        }
    }

    private func dispatch(_ message: RTMPMessage, type: RTMPChunkType) {
        switch message {
        case let message as RTMPSetChunkSizeMessage:
            chunkSizeC = Int(message.size)
        case let message as RTMPWindowAcknowledgementSizeMessage:
            windowSizeC = Int64(message.size)
            windowSizeS = Int64(message.size)
        case let message as RTMPSetPeerBandwidthMessage:
            bandWidth = message.size
        case let message as RTMPCommandMessage:
            guard let responder = operations.removeValue(forKey: message.transactionId) else {
                switch message.commandName {
                case "close":
                    close(isDisconnected: true)
                case "onFCPublish", "onFCUnpublish":
                    // The specification is undefined, ignores it because it cannot handle it properly.
                    logger.info(message.commandName, message.arguments)
                default:
                    Task {
                        await dispatch(.rtmpStatus, bubbles: false, data: arguments.first as Any?)
                    }
                }
                return
            }
            switch message.commandName {
            case "_result":
                responder.on(result: arguments)
            case "_error":
                responder.on(status: arguments)
            default:
                break
            }
        case let message as RTMPDataMessage:
            Task {
                await stream(by: message.streamId)?.dispatch(message)
            }
        case let message as RTMPSharedObjectMessage:
            guard let remotePath = uri?.absoluteWithoutQueryString else {
                return
            }
            let persistence = (message.flags[3] & 2) != 0
            Task {
                await RTMPSharedObject.getRemote(
                    withName: message.sharedObjectName,
                    remotePath: remotePath,
                    persistence: persistence).on(message: message)
            }
        case let message as RTMPAudioMessage:
            Task {
                await stream(by: message.streamId)?.append(message, type: type)
            }
        case let message as RTMPVideoMessage:
            Task {
                await stream(by: message.streamId)?.append(message, type: type)
            }
        case let message as RTMPUserControlMessage:
            switch message.event {
            case .ping:
                doOutput(chunk: RTMPChunk(
                    type: .zero,
                    streamId: RTMPChunk.StreamID.control.rawValue,
                    message: RTMPUserControlMessage(event: .pong, value: message.value)
                ))
            case .bufferEmpty:
                Task {
                    await stream(by: UInt32(message.value))?.dispatch(.rtmpStatus, bubbles: false, data: RTMPStream.Code.bufferEmpty.data(""))
                }
            case .bufferFull:
                Task {
                    await stream(by: UInt32(message.value))?.dispatch(.rtmpStatus, bubbles: false, data: RTMPStream.Code.bufferFull.data(""))
                }
            default:
                break
            }
        default:
            break
        }
    }

    func stream(by id: UInt32) async -> RTMPStream? {
        for stream in streams where await stream.id == id {
            return stream
        }
        return nil
    }
}

extension RTMPConnection: EventListener {
    // MARK: EventListener
    public func handleEvent(_ event: Event) {
        guard
            let data = event.data as? ASObject,
            let code = data["code"] as? String else {
            return
        }
        switch Code(rawValue: code) {
        case .some(.connectSuccess):
            connected = true
            chunkSizeS = chunkSize
            doOutput(chunk: RTMPChunk(
                type: .zero,
                streamId: RTMPChunk.StreamID.control.rawValue,
                message: RTMPSetChunkSizeMessage(UInt32(chunkSizeS))
            ))
        case .some(.connectRejected):
            guard
                let uri,
                let user = uri.user,
                let password = uri.password,
                let description = data["description"] as? String else {
                break
            }
            socket.close()
            switch true {
            case description.contains("reason=nosuchuser"):
                break
            case description.contains("reason=authfailed"):
                break
            case description.contains("reason=needauth"):
                let command = Self.makeSanJoseAuthCommand(uri, description: description)
                connect(command, arguments: arguments)
            case description.contains("authmod=adobe"):
                if user.isEmpty || password.isEmpty {
                    close(isDisconnected: true)
                    break
                }
                let query = uri.query ?? ""
                let command = uri.absoluteString + (query.isEmpty ? "?" : "&") + "authmod=adobe&user=\(user)"
                connect(command, arguments: arguments)
            default:
                break
            }
        case .some(.connectClosed):
            if let description = data["description"] as? String {
                logger.warn(description)
            }
            close(isDisconnected: true)
        default:
            break
        }
    }
}

extension RTMPConnection: EventDispatcherConvertible {
    // MARK: EventDispatcherConvertible
    public func addEventListener(_ type: Event.Name, listener: some EventListener, useCapture: Bool = false) async {
        await dispatcher.addEventListener(type, listener: listener, useCapture: useCapture)
    }

    public func removeEventListener(_ type: Event.Name, listener: some EventListener, useCapture: Bool = false) async {
        await dispatcher.removeEventListener(type, listener: listener, useCapture: useCapture)
    }

    public func dispatch(event: Event) async {
        await dispatcher.dispatch(event: event)
    }

    public func dispatch(_ type: Event.Name, bubbles: Bool, data: Any?) async {
        await dispatcher.dispatch(type, bubbles: bubbles, data: data)
    }
}
