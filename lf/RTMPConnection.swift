import Foundation

enum RTMPConnectionSupportVideo:UInt16 {
    case UNUSED = 0x001
    case JPEG = 0x002
    case SORENSON = 0x004
    case VP6 = 0x008
    case VP6ALPHA = 0x0010
    case HOMEBREWV = 0x0040
    case H264 = 0x0080
    case ALL = 0x00FF
}

enum RTMPConnectionSupportSound:UInt16 {
    case NONE = 0x001
    case ADPCM = 0x002
    case MP3 = 0x003
    case INTEL = 0x0008
    case UNSED = 0x0010
    case NELLY8 = 0x0020
    case NELLY = 0x0040
    case G711A = 0x0080
    case G711U = 0x0100
    case NELLY16 = 0x0200
    case AAC = 0x0400
    case SPEEX = 0x0800
    case ALL = 0x0FFF
}

enum RTMPConnectionVideoFunction:UInt8 {
    case CLIENT_SEEK = 1
}

public class RTMPConnection: EventDispatcher, RTMPSocketDelegate {
    static let defaultPort:UInt32 = 1935
    static let defaultObjectEncoding:UInt8 = 0x00
    static let defaultChunkSizeS:Int = 1024 * 16

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
            case .CHUNK_SIZE:
                let message:RTMPSetChunkSizeMessage = message as! RTMPSetChunkSizeMessage
                socket.chunkSizeC = Int(message.size)
                break
            case .ABORT:
                break
            case .ACK:
                onAcknowledgement(message as! RTMPAcknowledgementMessage)
                break
            case .USER:
                onUserControl(message as! RTMPUserControlMessage)
                break
            case .WINDOW_ACK:
                onWindowAcknowledgementSize(message as! RTMPWindowAcknowledgementSizeMessage)
                break
            case .BANDWIDTH:
                let message:RTMPSetPeerBandwidthMessage = message as! RTMPSetPeerBandwidthMessage
                bandWidth = message.size
                break
            case .AUDIO:
                break
            case .VIDEO:
                break
            case .AMF0_COMMAND, .AMF3_COMMAND:
                onCommandMessage(message as! RTMPCommandMessage)
                break
            case .UNKNOW:
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
    
    func didSetReadyState(socket: RTMPSocket, readyState: RTMPSocketReadyState) {
        switch socket.readyState {
        case .INITIALIZED:
            break
        case .VERSION_SENT:
            break
        case .ACK_SENT:
            break
        case .HANDSHAKE_DONE:
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
        case RTMPUserControlEvent.STREAM_BEGIN:
            break;
        case RTMPUserControlEvent.STREAM_EOF:
            break;
        case RTMPUserControlEvent.STREAM_DRY:
            break;
        case RTMPUserControlEvent.PING:
            socket.doWrite(RTMPChunk(message: RTMPUserControlMessage(event: RTMPUserControlEvent.PONG)))
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
                "flashVer": "FME/3.0 (compatible; FMSc/1.0)",
                "swfUrl": _uri,
                "tcUrl": _uri,
                "fpad": false,
                "capabilities": 0,
                "audioCodecs": RTMPConnectionSupportSound.AAC.rawValue,
                "videoCodecs": RTMPConnectionSupportVideo.H264.rawValue,
                "videoFunction": RTMPConnectionVideoFunction.CLIENT_SEEK.rawValue,
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
