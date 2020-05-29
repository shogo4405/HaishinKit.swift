import AVFoundation
import Foundation

/**
 flash.net.Responder for Swift
 */
open class Responder {
    public typealias Handler = (_ data: [Any?]) -> Void

    private var result: Handler
    private var status: Handler?

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

// MARK: -
/**
 flash.net.NetConnection for Swift
 */
open class RTMPConnection: EventDispatcher {
    public static let defaultWindowSizeS: Int64 = 250000
    public static let supportedProtocols: Set<String> = ["rtmp", "rtmps", "rtmpt", "rtmpts"]
    public static let defaultPort: Int = 1935
    public static let defaultFlashVer: String = "FMLE/3.0 (compatible; FMSc/1.0)"
    public static let defaultChunkSizeS: Int = 1024 * 8
    public static let defaultCapabilities: Int = 239
    public static let defaultObjectEncoding: RTMPObjectEncoding = .amf0

    /**
     NetStatusEvent#info.code for NetConnection
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
                return "status"
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
                return "status"
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

    private static func createSanJoseAuthCommand(_ url: URL, description: String) -> String {
        var command: String = url.absoluteString

        guard let index: String.Index = description.firstIndex(of: "?") else {
            return command
        }

        let query = String(description[description.index(index, offsetBy: 1)...])
        let challenge = String(format: "%08x", UInt32.random(in: 0...UInt32.max))
        let dictionary: [String: String] = URL(string: "http://localhost?" + query)!.dictionaryFromQuery()

        var response: String = MD5.base64("\(url.user!)\(dictionary["salt"]!)\(url.password!)")
        if let opaque: String = dictionary["opaque"] {
            command += "&opaque=\(opaque)"
            response += opaque
        } else if let challenge: String = dictionary["challenge"] {
            response += challenge
        }

        response = MD5.base64("\(response)\(challenge)")
        command += "&challenge=\(challenge)&response=\(response)"

        return command
    }

    /// The URL of .swf.
    open var swfUrl: String?
    /// The URL of an HTTP referer.
    open var pageUrl: String?
    /// The time to wait for TCP/IP Handshake done.
    open var timeout: Int {
        get { socket.timeout }
        set { socket.timeout = newValue }
    }
    open var qualityOfService: DispatchQoS {
        get { socket.qualityOfService }
        set { socket.qualityOfService = newValue }
    }
    /// The name of application.
    open var flashVer: String = RTMPConnection.defaultFlashVer
    /// The outgoing RTMPChunkSize.
    open var chunkSize: Int = RTMPConnection.defaultChunkSizeS
    /// The URI passed to the RTMPConnection.connect() method.
    open private(set) var uri: URL?
    /// This instance connected to server(true) or not(false).
    open private(set) var connected = false
    /// This instance requires Network.framework if possible.
    open var requireNetworkFramework = false
    /// The socket optional parameters.
    open var parameters: Any?
    /// The object encoding for this RTMPConnection instance.
    open var objectEncoding: RTMPObjectEncoding = RTMPConnection.defaultObjectEncoding
    /// The statistics of total incoming bytes.
    open var totalBytesIn: Int64 {
        socket.totalBytesIn.value
    }
    /// The statistics of total outgoing bytes.
    open var totalBytesOut: Int64 {
        socket.totalBytesOut.value
    }
    /// The statistics of total RTMPStream counts.
    open var totalStreamsCount: Int {
        streams.count
    }
    /// The statistics of outgoing queue bytes per second.
    @objc open private(set) dynamic var previousQueueBytesOut: [Int64] = []
    /// The statistics of incoming bytes per second.
    @objc open private(set) dynamic var currentBytesInPerSecond: Int32 = 0
    /// The statistics of outgoing bytes per second.
    @objc open private(set) dynamic var currentBytesOutPerSecond: Int32 = 0

    var socket: RTMPSocketCompatible!
    var streams: [UInt32: RTMPStream] = [:]
    var sequence: Int64 = 0
    var bandWidth: UInt32 = 0
    var streamsmap: [UInt16: UInt32] = [:]
    var operations: [Int: Responder] = [:]
    var windowSizeC: Int64 = RTMPConnection.defaultWindowSizeS {
        didSet {
            guard socket.connected else {
                return
            }
            socket.doOutput(chunk: RTMPChunk(
                type: .zero,
                streamId: RTMPChunk.StreamID.control.rawValue,
                message: RTMPWindowAcknowledgementSizeMessage(UInt32(windowSizeC))
            ), locked: nil)
        }
    }
    var windowSizeS: Int64 = RTMPConnection.defaultWindowSizeS
    var currentTransactionId: Int = 0

    private var _audioEngine: AVAudioEngine?
    var audioEngine: AVAudioEngine! {
        get {
            if _audioEngine == nil {
                _audioEngine = AVAudioEngine()
            }
            return _audioEngine
        }
        set {
            _audioEngine = newValue
        }
    }

    private var timer: Timer? {
        didSet {
            oldValue?.invalidate()
            if let timer: Timer = timer {
                RunLoop.main.add(timer, forMode: .common)
            }
        }
    }
    private var messages: [UInt16: RTMPMessage] = [:]
    private var arguments: [Any?] = []
    private var currentChunk: RTMPChunk?
    private var measureInterval: Int = 3
    private var fragmentedChunks: [UInt16: RTMPChunk] = [:]
    private var previousTotalBytesIn: Int64 = 0
    private var previousTotalBytesOut: Int64 = 0

    override public init() {
        super.init()
        addEventListener(.rtmpStatus, selector: #selector(on(status:)))
    }

    deinit {
        timer = nil
        streams.removeAll()
        removeEventListener(.rtmpStatus, selector: #selector(on(status:)))
    }

    open func call(_ commandName: String, responder: Responder?, arguments: Any?...) {
        guard connected else {
            return
        }
        currentTransactionId += 1
        let message = RTMPCommandMessage(
            streamId: 0,
            transactionId: currentTransactionId,
            objectEncoding: objectEncoding,
            commandName: commandName,
            commandObject: nil,
            arguments: arguments
        )
        if responder != nil {
            operations[message.transactionId] = responder
        }
        socket.doOutput(chunk: RTMPChunk(message: message), locked: nil)
    }

    open func connect(_ command: String, arguments: Any?...) {
        guard let uri = URL(string: command), let scheme: String = uri.scheme, !connected && RTMPConnection.supportedProtocols.contains(scheme) else {
            return
        }
        self.uri = uri
        self.arguments = arguments
        timer = Timer(timeInterval: 1.0, target: self, selector: #selector(on(timer:)), userInfo: nil, repeats: true)
        switch scheme {
        case "rtmpt", "rtmpts":
            socket = socket is RTMPTSocket ? socket : RTMPTSocket()
        default:
            if #available(iOS 12.0, macOS 10.14, tvOS 12.0, *), requireNetworkFramework {
                socket = socket is RTMPNWSocket ? socket : RTMPNWSocket()
            } else {
                socket = socket is RTMPSocket ? socket : RTMPSocket()
            }
        }
        socket.delegate = self
        socket.setProperty(parameters, forKey: "parameters")
        socket.securityLevel = uri.scheme == "rtmps" || uri.scheme == "rtmpts"  ? .negotiatedSSL : .none
        socket.connect(withName: uri.host!, port: uri.port ?? RTMPConnection.defaultPort)
    }

    open func close() {
        close(isDisconnected: false)
    }

    func close(isDisconnected: Bool) {
        guard connected || isDisconnected else {
            timer = nil
            return
        }
        if !isDisconnected {
            uri = nil
        }
        for (id, stream) in streams {
            stream.close()
            streams.removeValue(forKey: id)
        }
        socket.close(isDisconnected: false)
        timer = nil
    }

    func createStream(_ stream: RTMPStream) {
        let responder = Responder(result: { data -> Void in
            guard let id: Double = data[0] as? Double else {
                return
            }
            stream.id = UInt32(id)
            self.streams[stream.id] = stream
            stream.readyState = .open
        })
        call("createStream", responder: responder)
    }

    @objc
    private func on(status: Notification) {
        let e = Event.from(status)

        guard
            let data: ASObject = e.data as? ASObject,
            let code: String = data["code"] as? String else {
            return
        }

        switch Code(rawValue: code) {
        case .some(.connectSuccess):
            connected = true
            socket.chunkSizeS = chunkSize
            socket.doOutput(chunk: RTMPChunk(
                type: .zero,
                streamId: RTMPChunk.StreamID.control.rawValue,
                message: RTMPSetChunkSizeMessage(UInt32(socket.chunkSizeS))
            ), locked: nil)
        case .some(.connectRejected):
            guard
                let uri: URL = uri,
                let user: String = uri.user,
                let password: String = uri.password,
                let description: String = data["description"] as? String else {
                break
            }
            socket.close(isDisconnected: false)
            switch true {
            case description.contains("reason=nosuchuser"):
                break
            case description.contains("reason=authfailed"):
                break
            case description.contains("reason=needauth"):
                let command: String = RTMPConnection.createSanJoseAuthCommand(uri, description: description)
                connect(command, arguments: arguments)
            case description.contains("authmod=adobe"):
                if user.isEmpty || password.isEmpty {
                    close(isDisconnected: true)
                    break
                }
                let query: String = uri.query ?? ""
                let command: String = uri.absoluteString + (query.isEmpty ? "?" : "&") + "authmod=adobe&user=\(user)"
                connect(command, arguments: arguments)
            default:
                break
            }
        case .some(.connectClosed):
            if let description: String = data["description"] as? String {
                logger.warn(description)
            }
            close(isDisconnected: true)
        default:
            break
        }
    }

    private func makeConnectionChunk() -> RTMPChunk? {
        guard let uri: URL = uri else {
            return nil
        }

        var app = String(uri.path[uri.path.index(uri.path.startIndex, offsetBy: 1)...])
        if let query: String = uri.query {
            app += "?" + query
        }

        currentTransactionId += 1

        let message = RTMPCommandMessage(
            streamId: 0,
            transactionId: currentTransactionId,
            // "connect" must be a objectEncoding = 0
            objectEncoding: .amf0,
            commandName: "connect",
            commandObject: [
                "app": app,
                "flashVer": flashVer,
                "swfUrl": swfUrl,
                "tcUrl": uri.absoluteWithoutAuthenticationString,
                "fpad": false,
                "capabilities": RTMPConnection.defaultCapabilities,
                "audioCodecs": SupportSound.aac.rawValue,
                "videoCodecs": SupportVideo.h264.rawValue,
                "videoFunction": VideoFunction.clientSeek.rawValue,
                "pageUrl": pageUrl,
                "objectEncoding": objectEncoding.rawValue
            ],
            arguments: arguments
        )

        return RTMPChunk(message: message)
    }

    @objc
    private func on(timer: Timer) {
        let totalBytesIn: Int64 = self.totalBytesIn
        let totalBytesOut: Int64 = self.totalBytesOut
        currentBytesInPerSecond = Int32(totalBytesIn - previousTotalBytesIn)
        currentBytesOutPerSecond = Int32(totalBytesOut - previousTotalBytesOut)
        previousTotalBytesIn = totalBytesIn
        previousTotalBytesOut = totalBytesOut
        previousQueueBytesOut.append(socket.queueBytesOut.value)
        for (_, stream) in streams {
            stream.on(timer: timer)
        }
        if measureInterval <= previousQueueBytesOut.count {
            var total: Int = 0
            for i in 0..<previousQueueBytesOut.count - 1 where previousQueueBytesOut[i] < previousQueueBytesOut[i + 1] {
                total += 1
            }
            if total == measureInterval - 1 {
                for (_, stream) in streams {
                    stream.delegate?.didPublishInsufficientBW(stream, withConnection: self)
                }
            } else if total == 0 {
                for (_, stream) in streams {
                    stream.delegate?.didPublishSufficientBW(stream, withConnection: self)
                }
            }
            previousQueueBytesOut.removeFirst()
        }
        for (_, stream) in streams {
            stream.delegate?.didStatics(stream, withConneciton: self)
        }
    }
}

extension RTMPConnection: RTMPSocketDelegate {
    // MARK: RTMPSocketDelegate
    func didSetReadyState(_ readyState: RTMPSocketReadyState) {
        logger.debug(readyState)
        switch readyState {
        case .handshakeDone:
            guard let chunk: RTMPChunk = makeConnectionChunk() else {
                close()
                break
            }
            socket.doOutput(chunk: chunk, locked: nil)
        case .closed:
            connected = false
            sequence = 0
            currentChunk = nil
            currentTransactionId = 0
            previousTotalBytesIn = 0
            previousTotalBytesOut = 0
            messages.removeAll()
            operations.removeAll()
            fragmentedChunks.removeAll()
        default:
            break
        }
    }

    func didSetTotalBytesIn(_ totalBytesIn: Int64) {
        guard windowSizeS * (sequence + 1) <= totalBytesIn else {
            return
        }
        socket.doOutput(chunk: RTMPChunk(
            type: sequence == 0 ? .zero : .one,
            streamId: RTMPChunk.StreamID.control.rawValue,
            message: RTMPAcknowledgementMessage(UInt32(totalBytesIn))
        ), locked: nil)
        sequence += 1
    }

    func listen(_ data: Data) {
        guard let chunk: RTMPChunk = currentChunk ?? RTMPChunk(data, size: socket.chunkSizeC) else {
            socket.inputBuffer.append(data)
            return
        }

        var position: Int = chunk.data.count
        if (4 <= chunk.data.count) && (chunk.data[1] == 0xFF) && (chunk.data[2] == 0xFF) && (chunk.data[3] == 0xFF) {
            position += 4
        }

        if currentChunk != nil {
            position = chunk.append(data, size: socket.chunkSizeC)
        }
        if chunk.type == .two {
            position = chunk.append(data, message: messages[chunk.streamId])
        }
        if chunk.type == .three && fragmentedChunks[chunk.streamId] == nil {
            position = chunk.append(data, message: messages[chunk.streamId])
        }

        if let message: RTMPMessage = chunk.message, chunk.ready {
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
            message.execute(self, type: chunk.type)
            currentChunk = nil
            messages[chunk.streamId] = message
            if 0 < position && position < data.count {
                listen(data.advanced(by: position))
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
            listen(data.advanced(by: position))
        }
    }
}
