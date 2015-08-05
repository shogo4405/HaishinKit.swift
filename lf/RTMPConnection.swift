import Foundation

public class RTMPConnection: EventDispatcher, RTMPSocketDelegate {

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

    static let defaultPort:UInt32 = 1935
    static let defaultObjectEncoding:UInt8 = 0x00
    static let defaultChunkSizeS:Int = 1024 * 16
    static let defaultFlashVer:String = "FME/3.0 (compatible; FMSc/1.0)"

    private var _uri:String = ""
    public var uri:String {
        return _uri
    }

    public var objectEncoding:UInt8 = RTMPConnection.defaultObjectEncoding {
        didSet {
            socket.objectEncoding = objectEncoding
        }
    }

    private var _connected:Bool = false
    public var connected:Bool {
        return _connected
    }

    var currentTransactionId:Int = 0

    private var socket:RTMPSocket = RTMPSocket()
    private var bandWidth:Int32 = 0
    private var operations:Dictionary<Int, Responder> = [:]
    private var rtmpStreams:Dictionary<UInt32, RTMPStream> = [:]
    private var currentChunk:RTMPChunk? = nil

    override public init() {
        super.init()
        socket.delegate = self
    }
    
    public func call(commandName:String, responder:Responder?, arguments:AnyObject...) {
        let message:RTMPCommandMessage = RTMPCommandMessage(
            streamId: RTMPChunkStreamId.COMMAND.rawValue,
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
    
    public func connect(command:String, arguments:NSObject...) {
        var url:NSURL = NSURL(string: command)!
        _uri = command
        addEventListener("rtmpStatus", selector: "rtmpStatusHandler:")
        socket.connect(url.host!, port: 1935)
    }
    
    public func close() {
        _uri = ""
        removeEventListener("rtmpStatus", selector: "rtmpStatusHandler:")
        socket.close()
    }

    func doWrite(chunk: RTMPChunk) {
        socket.doWrite(chunk)
    }

    func createStream(rtmpStream: RTMPStream) {
        let responder:Responder = Responder { (data) -> Void in
            var id:Any? = data[0]
            if let id:Double = id as? Double {
                rtmpStream.id = UInt32(id)
                self.rtmpStreams[rtmpStream.id] = rtmpStream
                rtmpStream.readyState = RTMPStreamReadyState.OPEN
            }
        }
        call("createStream", responder: responder)
    }

    func listen(socket:RTMPSocket, bytes:[UInt8]) {

        let chunk:RTMPChunk? = currentChunk == nil ? RTMPChunk(bytes: bytes) : currentChunk

        if (chunk == nil) {
            return
        }

        var position:Int = chunk!.bytes.count
        if (currentChunk != nil) {
            position = chunk!.message!.append(bytes, chunkSize: socket.chunkSizeC)
        }

        let message:RTMPMessage? = chunk!.message
        if (message!.ready) {
            println(chunk)
            switch message!.type {
            case .ChunkSize:
                let message:RTMPSetChunkSizeMessage = message as! RTMPSetChunkSizeMessage
                socket.chunkSizeC = Int(message.size)
                break
            case .Abort:
                break
            case .Ack:
                onAcknowledgement(message as! RTMPAcknowledgementMessage)
                break
            case .User:
                onUserControl(message as! RTMPUserControlMessage)
                break
            case .WindowAck:
                onWindowAcknowledgementSize(message as! RTMPWindowAcknowledgementSizeMessage)
                break
            case .Bandwidth:
                let message:RTMPSetPeerBandwidthMessage = message as! RTMPSetPeerBandwidthMessage
                bandWidth = message.size
                break
            case .Audio:
                break
            case .Video:
                break
            case .AMF0Command, .AMF3Command:
                onCommandMessage(message as! RTMPCommandMessage)
                break
            case .Unknown:
                break
            default:
                break
            }

            if (currentChunk == nil) {
                listen(socket, bytes: Array(bytes[chunk!.headerSize + message!.payload.count..<bytes.count]))
            } else {
                currentChunk = nil
                listen(socket, bytes: Array(bytes[position..<bytes.count]))
            }
            
            return
        }

        currentChunk = chunk
        if (position < bytes.count) {
            listen(socket, bytes: Array(bytes[position..<bytes.count]))
        }
    }
    
    func didSetReadyState(socket: RTMPSocket, readyState: RTMPSocket.ReadyState) {
        switch socket.readyState {
        case .Initialized:
            break
        case .VersionSent:
            break
        case .AckSent:
            break
        case .HandshakeDone:
            socket.doWrite(createConnectionChunk())
            break
        default:
            break
        }
    }

    private func onAcknowledgement(message:RTMPAcknowledgementMessage) {
    }

    private func onWindowAcknowledgementSize(message:RTMPWindowAcknowledgementSizeMessage) {
    }

    private func onUserControl(message:RTMPUserControlMessage) {
        switch message.event {
        case .Ping:
            socket.doWrite(RTMPChunk(message: RTMPUserControlMessage(event: RTMPUserControlMessage.Event.Pong)))
            break;
        default:
            break;
        }
    }

    private func onCommandMessage(message:RTMPCommandMessage) {

        let transactionId:Int = message.transactionId

        if (operations[transactionId] == nil) {
            dispatchEventWith("rtmpStatus", bubbles: false, data: message.arguments[0])
            return
        }

        let responder:Responder = operations.removeValueForKey(transactionId)!
        switch message.commandName {
        case "_result":
            responder.onResult(message.arguments)
            break
        case "_error":
            responder.onStatus(message.arguments)
            break
        default:
            break;
        }
    }

    private func createConnectionChunk() -> RTMPChunk {
        let url:NSURL = NSURL(string: _uri)!
        let path:String = url.path!
        var app:String = path.substringFromIndex(advance(path.startIndex, 1))
        
        if (url.query != nil) {
            app += "?" + url.query!
        }
        
        let message:RTMPCommandMessage = RTMPCommandMessage(
            streamId: 3,
            transactionId: ++currentTransactionId,
            objectEncoding: objectEncoding,
            commandName: "connect",
            commandObject: [
                "app": app,
                "flashVer": RTMPConnection.defaultFlashVer,
                "swfUrl": _uri,
                "tcUrl": _uri,
                "fpad": false,
                "capabilities": 0,
                "audioCodecs": SupportSound.AAC.rawValue,
                "videoCodecs": SupportVideo.H264.rawValue,
                "videoFunction": VideoFunction.ClientSeek.rawValue,
                "pageUrl": nil,
                "objectEncoding": objectEncoding
            ],
            arguments: []
        )

        return RTMPChunk(message: message)
    }

    func rtmpStatusHandler(notification: NSNotification) {
        let e:Event = Event.from(notification)
        if let data:ECMAObject = e.data as? ECMAObject {
            if let code:String = data["code"] as? String {
                switch code {
                case "NetConnection.Connect.Success":
                    _connected = true
                    socket.chunkSizeS = RTMPConnection.defaultChunkSizeS
                    socket.doWrite(RTMPChunk(message: RTMPSetChunkSizeMessage(size: Int32(socket.chunkSizeS))))
                    break
                default:
                    break
                }
            }
        }
    }
}
