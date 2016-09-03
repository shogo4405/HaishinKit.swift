import Foundation

/**
 flash.net.Responder for Swift
 */
open class Responder: NSObject {

    fileprivate var result:(_ data:[Any?]) -> Void
    fileprivate var status:((_ data:[Any?]) -> Void)?

    public init(result:@escaping (_ data:[Any?]) -> Void, status:((_ data:[Any?]) -> Void)?) {
        self.result = result
        self.status = status
    }

    convenience public init (result:@escaping (_ data:[Any?]) -> Void) {
        self.init(result: result, status: nil)
    }

    func onResult(_ data:[Any?]) {
        result(data)
    }

    func onStatus(_ data:[Any?]) {
        status?(data)
        status = nil
    }
}

// MARK: -
/**
 flash.net.NetConnection for Swift
 */
open class RTMPConnection: EventDispatcher {
    static open let supportedProtocols:[String] = ["rtmp", "rtmps"]

    /**
     NetStatusEvent#info.code for NetConnection
     */
    public enum Code: String {
        case CallBadVersion       = "NetConnection.Call.BadVersion"
        case CallFailed           = "NetConnection.Call.Failed"
        case CallProhibited       = "NetConnection.Call.Prohibited"
        case ConnectAppshutdown   = "NetConnection.Connect.AppShutdown"
        case ConnectClosed        = "NetConnection.Connect.Closed"
        case ConnectFailed        = "NetConnection.Connect.Failed"
        case ConnectIdleTimeOut   = "NetConnection.Connect.IdleTimeOut"
        case ConenctInvalidApp    = "NetConnection.Connect.InvalidApp"
        case ConnectNetworkChange = "NetConnection.Connect.NetworkChange"
        case ConnectRejected      = "NetConnection.Connect.Rejected"
        case ConnectSuccess       = "NetConnection.Connect.Success"

        public var level:String {
            switch self {
            case .CallBadVersion:
                return "error"
            case .CallFailed:
                return "error"
            case .CallProhibited:
                return "error"
            case .ConnectAppshutdown:
                return "status"
            case .ConnectClosed:
                return "status"
            case .ConnectFailed:
                return "error"
            case .ConnectIdleTimeOut:
                return "status"
            case .ConenctInvalidApp:
                return "error"
            case .ConnectNetworkChange:
                return "status"
            case .ConnectRejected:
                return "status"
            case .ConnectSuccess:
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

    enum SupportVideo: UInt16 {
        case unused    = 0x0001
        case jpeg      = 0x0002
        case sorenson  = 0x0004
        case homebrew  = 0x0008
        case vp6       = 0x0010
        case vp6Alpha  = 0x0020
        case homebrewv = 0x0040
        case h264      = 0x0080
        case all       = 0x00FF
    }

    enum SupportSound: UInt16 {
        case none    = 0x0001
        case adpcm   = 0x0002
        case mp3     = 0x0004
        case intel   = 0x0008
        case unused  = 0x0010
        case nelly8  = 0x0020
        case nelly   = 0x0040
        case g711A   = 0x0080
        case g711U   = 0x0100
        case nelly16 = 0x0200
        case aac     = 0x0400
        case speex   = 0x0800
        case all     = 0x0FFF
    }

    enum VideoFunction: UInt8 {
        case clientSeek = 1
    }

    fileprivate static func createSanJoseAuthCommand(_ url:URL, description:String) -> String {
        var command:String = url.absoluteString

        guard let index:String.CharacterView.Index = description.characters.index(of: "?") else {
            return command
        }

        let query:String = description.substring(from: description.characters.index(index, offsetBy: 1))
        let challenge:String = String(format: "%08x", arc4random())
        let dictionary:[String:String] = URL(string: "http://localhost?" + query)!.dictionaryFromQuery()

        var response:String = MD5.base64("\(url.user!)\(dictionary["salt"]!)\(url.password!)")
        if let opaque:String = dictionary["opaque"] {
            command += "&opaque=\(opaque)"
            response += opaque
        } else if let challenge:String = dictionary["challenge"] {
            response += challenge
        }

        response = MD5.base64("\(response)\(challenge)")
        command += "&challenge=\(challenge)&response=\(response)"

        return command
    }

    static let defaultPort:Int = 1935
    static let defaultFlashVer:String = "FMLE/3.0 (compatible; FMSc/1.0)"
    static let defaultChunkSizeS:Int = 1024 * 8
    static let defaultCapabilities:Int = 239
    static let defaultObjectEncoding:UInt8 = 0x00

    /// The URL of .swf.
    open var swfUrl:String? = nil
    /// The URL of an HTTP referer.
    open var pageUrl:String? = nil
    /// The time to wait for TCP/IP Handshake done.
    open var timeout:Int64 {
        get { return socket.timeout }
        set { socket.timeout = newValue }
    }
    /// The name of application.
    open var flashVer:String = RTMPConnection.defaultFlashVer
    /// The outgoing RTMPChunkSize.
    open var chunkSize:Int = RTMPConnection.defaultChunkSizeS
    /// The URI passed to the RTMPConnection.connect() method.
    open fileprivate(set) var uri:URL? = nil
    /// This instance connected to server(true) or not(false).
    open fileprivate(set) var connected:Bool = false
    /// The object encoding for this RTMPConnection instance.
    open var objectEncoding:UInt8 = RTMPConnection.defaultObjectEncoding {
        didSet {
            socket.objectEncoding = objectEncoding
        }
    }
    /// The statistics of total incoming bytes.
    open var totalBytesIn:Int64 {
        return socket.totalBytesIn
    }
    /// The statistics of total outgoing bytes.
    open var totalBytesOut:Int64 {
        return socket.totalBytesOut
    }
    /// The statistics of incoming bytes per second.
    dynamic open fileprivate(set) var currentBytesInPerSecond:Int32 = 0
    /// The statistics of outgoing bytes per second.
    dynamic open fileprivate(set) var currentBytesOutPerSecond:Int32 = 0

    var socket:RTMPSocket = RTMPSocket()
    var streams:[UInt32: RTMPStream] = [:]
    var bandWidth:UInt32 = 0
    var streamsmap:[UInt16: UInt32] = [:]
    var operations:[Int: Responder] = [:]
    var currentTransactionId:Int = 0

    fileprivate var timer:Timer? {
        didSet {
            if let oldValue:Timer = oldValue {
                oldValue.invalidate()
            }
            if let timer:Timer = timer {
                RunLoop.main.add(timer, forMode: RunLoopMode.commonModes)
            }
        }
    }
    fileprivate var messages:[UInt16:RTMPMessage] = [:]
    fileprivate var arguments:[Any?] = []
    fileprivate var currentChunk:RTMPChunk? = nil
    fileprivate var fragmentedChunks:[UInt16:RTMPChunk] = [:]
    fileprivate var previousTotalBytesIn:Int64 = 0
    fileprivate var previousTotalBytesOut:Int64 = 0

    override public init() {
        super.init()
        socket.delegate = self
        addEventListener(Event.RTMP_STATUS, selector: #selector(RTMPConnection.rtmpStatusHandler(_:)))
    }

    deinit {
        timer = nil
        removeEventListener(Event.RTMP_STATUS, selector: #selector(RTMPConnection.rtmpStatusHandler(_:)))
    }

    open func call(_ commandName:String, responder:Responder?, arguments:Any?...) {
        guard connected else {
            return
        }
        currentTransactionId += 1
        let message:RTMPCommandMessage = RTMPCommandMessage(
            streamId: 0,
            transactionId: currentTransactionId,
            objectEncoding: objectEncoding,
            commandName: commandName,
            commandObject: nil,
            arguments: arguments
        )
        if (responder != nil) {
            operations[message.transactionId] = responder
        }
        socket.doOutput(chunk: RTMPChunk(message: message))
    }

    @available(*, unavailable)
    open func connect(_ command:String) {
        connect(command, arguments: nil)
    }

    open func connect(_ command: String, arguments: Any?...) {
        guard let uri:URL = URL(string: command) , !connected && RTMPConnection.supportedProtocols.contains(uri.scheme!) else {
            return
        }
        self.uri = uri
        self.arguments = arguments
        timer = Timer(timeInterval: 1.0, target: self, selector: #selector(RTMPConnection.didTimerInterval(_:)), userInfo: nil, repeats: true)
        socket.securityLevel = uri.scheme == "rtmps" ? .negotiatedSSL : .none
        socket.connect(uri.host!, port: (uri as NSURL).port == nil ? RTMPConnection.defaultPort : (uri as NSURL).port!.intValue)
    }

    open func close() {
        close(false)
    }

    func close(_ disconnect:Bool) {
        guard connected || disconnect else {
            return
        }
        if (!disconnect) {
            uri = nil
        }
        for (id, stream) in streams {
            stream.close()
            streams.removeValue(forKey: id)
        }
        socket.close(false)
        timer = nil
    }

    func createStream(_ stream: RTMPStream) {
        let responder:Responder = Responder { (data) -> Void in
            let id:Any? = data[0]
            if let id:Double = id as? Double {
                stream.id = UInt32(id)
                self.streams[stream.id] = stream
                stream.readyState = .open
            }
        }
        call("createStream", responder: responder)
    }

    func rtmpStatusHandler(_ notification: Notification) {
        let e:Event = Event.from(notification)

        guard let data:ASObject = e.data as? ASObject, let code:String = data["code"] as? String else {
            return
        }

        switch code {
        case Code.ConnectSuccess.rawValue:
            connected = true
            socket.chunkSizeS = chunkSize
            socket.doOutput(chunk: RTMPChunk(
                type: .one,
                streamId: RTMPChunk.control,
                message: RTMPSetChunkSizeMessage(size: UInt32(socket.chunkSizeS))
            ))
        case Code.ConnectRejected.rawValue:
            guard let uri:URL = uri, let user:String = uri.user, let password:String = uri.password else {
                break
            }
            socket.deinitConnection(false)
            let description:String = data["description"] as! String
            switch true {
            case description.contains("reason=nosuchuser"):
                break
            case description.contains("reason=authfailed"):
                break
            case description.contains("reason=needauth"):
                let command:String = RTMPConnection.createSanJoseAuthCommand(uri, description: description)
                connect(command, arguments: arguments)
            case description.contains("authmod=adobe"):
                if (user == "" || password == "") {
                    close(true)
                    break
                }
                let query:String = uri.query ?? ""
                let command:String = uri.absoluteString + (query == "" ? "?" : "&") + "authmod=adobe&user=\(user)"
                connect(command, arguments: arguments)
            default:
                break
            }
        case Code.ConnectClosed.rawValue:
            close(true)
        default:
            break
        }
    }

    func didTimerInterval(_ timer:Timer) {
        let totalBytesIn:Int64 = self.totalBytesIn
        let totalBytesOut:Int64 = self.totalBytesOut
        currentBytesInPerSecond = Int32(totalBytesIn - previousTotalBytesIn)
        currentBytesOutPerSecond = Int32(totalBytesOut - previousTotalBytesOut)
        previousTotalBytesIn = totalBytesIn
        previousTotalBytesOut = totalBytesOut
        for (_, stream) in streams {
            stream.didTimerInterval(timer)
        }
    }

    fileprivate func createConnectionChunk() -> RTMPChunk? {
        guard let uri:URL = uri else {
            return nil
        }

        var app:String = uri.path.substring(from: uri.path.characters.index(uri.path.startIndex, offsetBy: 1))
        if let query:String = uri.query {
            app += "?" + query
        }

        currentTransactionId += 1

        let message:RTMPCommandMessage = RTMPCommandMessage(
            streamId: 0,
            transactionId: currentTransactionId,
            // "connect" must be a objectEncoding = 0
            objectEncoding: 0,
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
                "objectEncoding": objectEncoding
            ],
            arguments: arguments
        )

        return RTMPChunk(message: message)
    }
}

// MARK: RTMPSocketDelegate
extension RTMPConnection: RTMPSocketDelegate {

    func didSetReadyState(_ socket: RTMPSocket, readyState: RTMPSocket.ReadyState) {
        switch socket.readyState {
        case .handshakeDone:
            guard let chunk:RTMPChunk = createConnectionChunk() else {
                close()
                break
            }
            socket.doOutput(chunk: chunk)
        case .closed:
            connected = false
            currentChunk = nil
            currentTransactionId = 0
            messages.removeAll()
            operations.removeAll()
            fragmentedChunks.removeAll()
        default:
            break
        }
    }

    func listen(_ socket:RTMPSocket, bytes:[UInt8]) {
        guard let chunk:RTMPChunk = currentChunk ?? RTMPChunk(bytes: bytes, size: socket.chunkSizeC) else {
            socket.inputBuffer.append(contentsOf: bytes)
            return
        }

        var position:Int = chunk.bytes.count
        if (currentChunk != nil) {
            position = chunk.append(bytes, size: socket.chunkSizeC)
        }
        if (chunk.type == .two) {
            position = chunk.append(bytes, message: messages[chunk.streamId])
        }

        if let message:RTMPMessage = chunk.message , chunk.ready {
            if (logger.isEnabledForLogLevel(.verbose)) {
                logger.verbose(chunk.description)
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
            message.execute(self)
            currentChunk = nil
            messages[chunk.streamId] = message
            listen(socket, bytes: Array(bytes[position..<bytes.count]))
            return
        }

        if (chunk.fragmented) {
            fragmentedChunks[chunk.streamId] = chunk
            currentChunk = nil
        } else {
            currentChunk = chunk.type == .three ? fragmentedChunks[chunk.streamId] : chunk
            fragmentedChunks.removeValue(forKey: chunk.streamId)
        }

        if (position < bytes.count) {
            listen(socket, bytes: Array(bytes[position..<bytes.count]))
        }
    }
}
