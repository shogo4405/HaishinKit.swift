import Foundation

/**
 flash.net.Responder for Swift
 */
public class Responder {

    private var result:(data:[Any?]) -> Void
    private var status:((data:[Any?]) -> Void)?

    public init(result:(data:[Any?]) -> Void, status:((data:[Any?]) -> Void)?) {
        self.result = result
        self.status = status
    }

    convenience public init (result:(data:[Any?]) -> Void) {
        self.init(result: result, status: nil)
    }

    func onResult(data:[Any?]) {
        result(data: data)
    }

    func onStatus(data:[Any?]) {
        status?(data: data)
        status = nil
    }
}

// MARK: -
/**
 flash.net.NetConnection for Swift
 */
public class RTMPConnection: EventDispatcher {

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

        func data(description:String) -> ASObject {
            return [
                "code": self.rawValue,
                "level": self.level,
                "description": description,
            ]
        }
    }

    enum SupportVideo: UInt16 {
        case Unused    = 0x0001
        case Jpeg      = 0x0002
        case Sorenson  = 0x0004
        case Homebrew  = 0x0008
        case Vp6       = 0x0010
        case Vp6Alpha  = 0x0020
        case Homebrewv = 0x0040
        case H264      = 0x0080
        case All       = 0x00FF
    }

    enum SupportSound: UInt16 {
        case None    = 0x0001
        case ADPCM   = 0x0002
        case MP3     = 0x0004
        case Intel   = 0x0008
        case Unused  = 0x0010
        case Nelly8  = 0x0020
        case Nelly   = 0x0040
        case G711A   = 0x0080
        case G711U   = 0x0100
        case Nelly16 = 0x0200
        case AAC     = 0x0400
        case Speex   = 0x0800
        case All     = 0x0FFF
    }

    enum VideoFunction: UInt8 {
        case ClientSeek = 1
    }

    private static func createSanJoseAuthCommand(url:NSURL, description:String) -> String {
        var command:String = url.absoluteString

        guard let index:String.CharacterView.Index = description.characters.indexOf("?") else {
            return command
        }

        let query:String = description.substringFromIndex(index.advancedBy(1))
        let challenge:String = String(format: "%08x", random())
        let dictionary:[String:AnyObject] = NSURL(string: "http://localhost?" + query)!.dictionaryFromQuery()

        var response:String = MD5.base64("\(url.user!)\(dictionary["salt"]!)\(url.password!)")
        if let opaque:String = dictionary["opaque"] as? String {
            command += "&opaque=\(opaque)"
            response += opaque
        } else if let challenge:String = dictionary["challenge"] as? String {
            response += challenge
        }

        response = MD5.base64("\(response)\(challenge)")
        command += "&challenge=\(challenge)&response=\(response)"

        return command
    }

    static let defaultPort:Int = 1935
    static let defaultFlashVer:String = "FME/3.0 (compatible; FMSc/1.0)"
    static let defaultChunkSizeS:Int = 1024
    static let defaultCapabilities:Int = 239
    static let defaultObjectEncoding:UInt8 = 0x00

    public var swfUrl:String? = nil
    public var pageUrl:String? = nil
    public var flashVer:String = RTMPConnection.defaultFlashVer

    public private(set) var uri:NSURL? = nil
    public private(set) var connected:Bool = false

    public var objectEncoding:UInt8 = RTMPConnection.defaultObjectEncoding {
        didSet {
            socket.objectEncoding = objectEncoding
        }
    }

    var currentTransactionId:Int = 0
    var socket:RTMPSocket = RTMPSocket()
    var streams:[UInt32: RTMPStream] = [:]
    var bandWidth:UInt32 = 0
    var streamsmap:[UInt16: UInt32] = [:]
    var operations:[Int: Responder] = [:]

    private var messages:[UInt16:RTMPMessage] = [:]
    private var arguments:[Any?] = []
    private var currentChunk:RTMPChunk? = nil
    private var fragmentedChunks:[UInt16:RTMPChunk] = [:]

    override public init() {
        super.init()
        socket.delegate = self
        addEventListener(Event.RTMP_STATUS, selector: #selector(RTMPConnection.rtmpStatusHandler(_:)))
    }

    deinit {
        removeEventListener(Event.RTMP_STATUS, selector: #selector(RTMPConnection.rtmpStatusHandler(_:)))
    }

    public func call(commandName:String, responder:Responder?, arguments:AnyObject...) {
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

    public func connect(command: String, arguments: Any?...) {
        guard let uri:NSURL = NSURL(string: command) where !connected else {
            return
        }
        self.uri = uri
        self.arguments = arguments
        currentChunk = nil
        messages.removeAll()
        operations.removeAll()
        fragmentedChunks.removeAll()
        currentTransactionId = 0
        socket.connect(uri.host!, port: uri.port == nil ? RTMPConnection.defaultPort : uri.port!.integerValue)
    }

    public func close() {
        close(false)
    }

    func close(disconnect:Bool) {
        guard connected || disconnect else {
            return
        }
        if (!disconnect) {
            uri = nil
        }
        for (id, stream) in streams {
            stream.close()
            streams.removeValueForKey(id)
        }
        socket.close(false)
    }

    func createStream(stream: RTMPStream) {
        let responder:Responder = Responder { (data) -> Void in
            let id:Any? = data[0]
            if let id:Double = id as? Double {
                stream.id = UInt32(id)
                self.streams[stream.id] = stream
                stream.readyState = .Open
            }
        }
        call("createStream", responder: responder)
    }

    func rtmpStatusHandler(notification: NSNotification) {
        let e:Event = Event.from(notification)
        if let data:ASObject = e.data as? ASObject, code:String = data["code"] as? String {
            switch code {
            case Code.ConnectSuccess.rawValue:
                connected = true
                socket.chunkSizeS = RTMPConnection.defaultChunkSizeS
                socket.doOutput(chunk: RTMPChunk(
                    type: .One,
                    streamId: RTMPChunk.control,
                    message: RTMPSetChunkSizeMessage(size: UInt32(socket.chunkSizeS))
                ))
            case Code.ConnectRejected.rawValue:
                guard let uri:NSURL = uri, user:String = uri.user, _:String = uri.password else {
                    break
                }
                let query:String = uri.query ?? ""
                let description:String = data["description"] as! String
                // Step 3
                if (description.containsString("reason=authfailed")) {
                    break
                }
                // Step 2
                if (description.containsString("reason=needauth")) {
                    let command:String = RTMPConnection.createSanJoseAuthCommand(uri, description: description)
                    connect(command, arguments: arguments)
                    break
                }
                // Step 1
                if (description.containsString("authmod=adobe")) {
                    let command:String = uri.absoluteString + (query == "" ? "?" : "&") + "authmod=adobe&user=\(user)"
                    connect(command, arguments: arguments)
                    break
                }
            case Code.ConnectClosed.rawValue:
                close(true)
            default:
                break
            }
        }
    }

    private func createConnectionChunk() -> RTMPChunk? {
        guard let uri:NSURL = uri, path:String = uri.path else {
            return nil
        }

        var app:String = path.substringFromIndex(path.startIndex.advancedBy(1))
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
                "audioCodecs": SupportSound.AAC.rawValue,
                "videoCodecs": SupportVideo.H264.rawValue,
                "videoFunction": VideoFunction.ClientSeek.rawValue,
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

    func didSetReadyState(socket: RTMPSocket, readyState: RTMPSocket.ReadyState) {
        switch socket.readyState {
        case .HandshakeDone:
            guard let chunk:RTMPChunk = createConnectionChunk() else {
                close()
                break
            }
            socket.doOutput(chunk: chunk)
        case .Closed:
            connected = false
        default:
            break
        }
    }

    func listen(socket:RTMPSocket, bytes:[UInt8]) {
        guard let chunk:RTMPChunk = currentChunk ?? RTMPChunk(bytes: bytes, size: socket.chunkSizeC) else {
            socket.inputBuffer += bytes
            return
        }

        var position:Int = chunk.bytes.count
        if (currentChunk != nil) {
            position = chunk.append(bytes, size: socket.chunkSizeC)
        }
        if (chunk.type == .Two) {
            position = chunk.append(bytes, message: messages[chunk.streamId])
        }

        if let message:RTMPMessage = chunk.message where chunk.ready {
            if (logger.isEnabledForLogLevel(.Verbose)) {
                logger.verbose(chunk.description)
            }
            switch chunk.type {
            case .Zero:
                streamsmap[chunk.streamId] = message.streamId
            case .One:
                if let streamId = streamsmap[chunk.streamId] {
                    message.streamId = streamId
                }
            case .Two:
                break
            case .Three:
                break
            }
            message.execute(self)
            messages[chunk.streamId] = message

            if (currentChunk == nil) {
                listen(socket, bytes: Array(bytes[chunk.bytes.count..<bytes.count]))
            } else {
                currentChunk = nil
                listen(socket, bytes: Array(bytes[position..<bytes.count]))
            }

            return
        }

        if (chunk.fragmented) {
            fragmentedChunks[chunk.streamId] = chunk
            currentChunk = nil
        } else {
            currentChunk = chunk.type == .Three ? fragmentedChunks[chunk.streamId] : chunk
            fragmentedChunks.removeValueForKey(chunk.streamId)
        }

        if (position < bytes.count) {
            listen(socket, bytes: Array(bytes[position..<bytes.count]))
        }
    }
}
