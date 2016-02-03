import Foundation

public class Responder: NSObject {
    
    private var result:(data:[Any?]) -> Void
    private var status:((data:[Any?]) -> Void)?
    
    public init (result:(data:[Any?]) -> Void, status:((data:[Any?]) -> Void)?) {
        self.result = result
        self.status = status
    }
    
    convenience public init (result:(data:[Any?]) -> Void) {
        self.init(result: result, status: nil)
    }
    
    public func onResult(data:[Any?]) {
        result(data: data)
    }
    
    public func onStatus(data:[Any?]) {
        status?(data: data)
        status = nil
    }
}

public class RTMPConnection: EventDispatcher, RTMPSocketDelegate {

    public enum Code:String {
        case ConnectFailed = "NetConnection.Connect.Failed"
        case ConnectClosed = "NetConnection.Connect.Closed"
        case ConnectSuccess = "NetConnection.Connect.Success"
        case ConnectRejected = "NetConnection.Connect.Rejected"
        case ConenctInvalidApp = "NetConnection.Connect.InvalidApp"
        case ConnectAppshutdown = "NetConnection.Connect.AppShutdown"
        case ConnectIdleTimeOut = "NetConnection.Connect.IdleTimeOut"
        case ConnectNetworkChange = "NetConnection.Connect.NetworkChange"
    }

    enum SupportVideo:UInt16 {
        case Unused = 0x001
        case Jpeg = 0x002
        case Sorenson = 0x004
        case Vp6 = 0x008
        case Vp6Alpha = 0x0010
        case Homebrew = 0x0040
        case H264 = 0x0080
        case All = 0x00FF
    }

    enum SupportSound:UInt16 {
        case None = 0x001
        case ADPCM = 0x002
        case MP3 = 0x003
        case Intel = 0x0008
        case Unused = 0x0010
        case Nelly8 = 0x0020
        case Nelly = 0x0040
        case G711A = 0x0080
        case G711U = 0x0100
        case Nelly16 = 0x0200
        case AAC = 0x0400
        case Speex = 0x0800
        case All = 0x0FFF
    }

    enum VideoFunction:UInt8 {
        case ClientSeek = 1
    }

    static func createSanJoseAuthCommand(url:NSURL, description:String) -> String {
        var command:String = url.absoluteString

        if let index:String.CharacterView.Index = description.characters.indexOf("?") {
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
        }

        return command
    }

    static let defaultPort:Int = 1935
    static let defaultObjectEncoding:UInt8 = 0x00
    static let defaultChunkSizeS:Int = 1024 * 16
    static let defaultFlashVer:String = "FME/3.0 (compatible; FMSc/1.0)"

    public private(set) var uri:NSURL? = nil
    public private(set) var connected:Bool = false

    public var objectEncoding:UInt8 = RTMPConnection.defaultObjectEncoding {
        didSet {
            socket.objectEncoding = objectEncoding
        }
    }

    var currentTransactionId:Int = 0
    var socket:RTMPSocket = RTMPSocket()
    var streams:[UInt32:RTMPStream] = [:]
    var bandWidth:UInt32 = 0
    var streamsmap:[UInt16:UInt32] = [:]
    var operations:[Int:Responder] = [:]

    private var arguments:[Any?] = []
    private var currentChunk:RTMPChunk? = nil
    private var fragmentedChunks:[UInt16:RTMPChunk] = [:]

    override public init() {
        super.init()
        socket.delegate = self
    }
    
    public func call(commandName:String, responder:Responder?, arguments:AnyObject...) {
        let message:RTMPCommandMessage = RTMPCommandMessage(
            streamId: UInt32(RTMPChunk.command),
            transactionId: ++currentTransactionId,
            objectEncoding: objectEncoding,
            commandName: commandName,
            commandObject: nil,
            arguments: arguments
        )
        if (responder != nil) {
            operations[message.transactionId] = responder
        }
        socket.doWrite(RTMPChunk(message: message))
    }

    public func connect(command: String, arguments: Any?...) {
        if let url:NSURL = NSURL(string: command) {
            uri = url
            self.arguments = arguments
            addEventListener(Event.RTMP_STATUS, selector: "rtmpStatusHandler:")
            socket.connect(url.host!, port: url.port == nil ? RTMPConnection.defaultPort : url.port!.integerValue)
        }
    }

    public func close() {
        uri = nil
        for (id, stream) in streams {
            stream.close()
            streams.removeValueForKey(id)
        }
        socket.close()
    }

    func doWrite(chunk: RTMPChunk) {
        socket.doWrite(chunk)
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

    func listen(socket:RTMPSocket, bytes:[UInt8]) {

        let chunk:RTMPChunk? = currentChunk == nil ? RTMPChunk(bytes: bytes, size: socket.chunkSizeC) : currentChunk

        if (chunk == nil) {
            socket.inputBuffer += bytes
            return
        }

        var position:Int = chunk!.bytes.count
        if (currentChunk != nil) {
            position = chunk!.append(bytes, size: socket.chunkSizeC)
        }

        if (chunk!.ready) {
            print(chunk!)

            let message:RTMPMessage = chunk!.message!
            switch chunk!.type {
            case .Zero:
                streamsmap[chunk!.streamId] = message.streamId
            case .One:
                message.streamId = streamsmap[chunk!.streamId]!
            case .Two:
                break
            case .Three:
                break
            }
            message.execute(self)

            if (currentChunk == nil) {
                listen(socket, bytes: Array(bytes[chunk!.bytes.count..<bytes.count]))
            } else {
                currentChunk = nil
                listen(socket, bytes: Array(bytes[position..<bytes.count]))
            }
            
            return
        }

        if (chunk!.fragmented) {
            fragmentedChunks[chunk!.streamId] = chunk
            currentChunk = nil
        } else {
            currentChunk = chunk!.type == .Three ? fragmentedChunks[chunk!.streamId] : chunk
            fragmentedChunks.removeValueForKey(chunk!.streamId)
        }

        if (position < bytes.count) {
            listen(socket, bytes: Array(bytes[position..<bytes.count]))
        }
    }

    func didSetReadyState(socket: RTMPSocket, readyState: RTMPSocket.ReadyState) {
        switch socket.readyState {
        case .HandshakeDone:
            socket.doWrite(createConnectionChunk())
        case .Closed:
            let data:ECMAObject = [
                "code": connected ? Code.ConnectClosed.rawValue : Code.ConnectFailed.rawValue
            ]
            connected = false
            dispatchEventWith(Event.RTMP_STATUS, bubbles: false, data: data)
        default:
            break
        }
    }

    private func createConnectionChunk() -> RTMPChunk {
        var app:String = uri!.path!.substringFromIndex(uri!.path!.startIndex.advancedBy(1))
        
        if (uri!.query != nil) {
            app += "?" + uri!.query!
        }
        
        let message:RTMPCommandMessage = RTMPCommandMessage(
            streamId: 3,
            transactionId: ++currentTransactionId,
            objectEncoding: objectEncoding,
            commandName: "connect",
            commandObject: [
                "app": app,
                "flashVer": RTMPConnection.defaultFlashVer,
                "swfUrl": uri!.absoluteWithoutAuthenticationString,
                "tcUrl": uri!.absoluteWithoutAuthenticationString,
                "fpad": false,
                "capabilities": 0,
                "audioCodecs": SupportSound.AAC.rawValue,
                "videoCodecs": SupportVideo.H264.rawValue,
                "videoFunction": VideoFunction.ClientSeek.rawValue,
                "pageUrl": nil,
                "objectEncoding": objectEncoding
            ],
            arguments: arguments
        )

        return RTMPChunk(message: message)
    }

    func rtmpStatusHandler(notification: NSNotification) {
        removeEventListener(Event.RTMP_STATUS, selector: "rtmpStatusHandler:")
        let e:Event = Event.from(notification)
        if let data:ECMAObject = e.data as? ECMAObject {
            if let code:String = data["code"] as? String {
                switch code {
                case Code.ConnectSuccess.rawValue:
                    connected = true
                    socket.chunkSizeS = RTMPConnection.defaultChunkSizeS
                    socket.doWrite(RTMPChunk(message: RTMPSetChunkSizeMessage(size: UInt32(socket.chunkSizeS))))
                case Code.ConnectRejected.rawValue:
                    guard uri?.user != nil && uri?.password != nil else {
                        break
                    }
                    let query:String = uri!.query ?? ""
                    let description:String = data["description"] as! String
                    // Step 3
                    if (description.containsString("reason=authfailed")) {
                        break
                    }
                    // Step 2
                    if (description.containsString("reason=needauth")) {
                        let command:String = RTMPConnection.createSanJoseAuthCommand(uri!, description: description)
                        connect(command, arguments: arguments)
                        break
                    }
                    // Step 1
                    if (description.containsString("authmod=adobe")) {
                        let command:String = uri!.absoluteString + (query == "" ? "?" : "&") + "authmod=adobe&user=\(uri!.user!)"
                        connect(command, arguments: arguments)
                        break
                    }
                default:
                    break
                }
            }
        }
    }
}
