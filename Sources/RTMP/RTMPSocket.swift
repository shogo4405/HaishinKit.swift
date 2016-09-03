import Foundation

// MARK: RTMPSocketDelegate
protocol RTMPSocketDelegate: IEventDispatcher {
    func listen(_ socket:RTMPSocket, bytes:[UInt8])
    func didSetReadyState(_ socket:RTMPSocket, readyState:RTMPSocket.ReadyState)
}

// MARK: -
final class RTMPSocket: NetSocket {

    enum ReadyState: UInt8 {
        case uninitialized = 0
        case versionSent   = 1
        case ackSent       = 2
        case handshakeDone = 3
        case closing       = 4
        case closed        = 5
    }

    static let sigSize:Int = 1536
    static let protocolVersion:UInt8 = 3
    static let defaultBufferSize:Int = 1024

    var readyState:ReadyState = .uninitialized {
        didSet {
            delegate?.didSetReadyState(self, readyState: readyState)
        }
    }
    var chunkSizeC:Int = RTMPChunk.defaultSize
    var chunkSizeS:Int = RTMPChunk.defaultSize
    var objectEncoding:UInt8 = RTMPConnection.defaultObjectEncoding
    weak var delegate:RTMPSocketDelegate? = nil
    override var connected:Bool {
        didSet {
            if (connected) {
                timestamp = Date().timeIntervalSince1970
                let c1packet:ByteArray = ByteArray()
                    .writeInt32(Int32(timestamp))
                    .writeBytes([0x00, 0x00, 0x00, 0x00])
                for _ in 0..<RTMPSocket.sigSize - 8 {
                    c1packet.writeUInt8(UInt8(arc4random_uniform(0xff)))
                }
                doOutput(bytes: [RTMPSocket.protocolVersion])
                doOutput(bytes: c1packet.bytes)
                readyState = .versionSent
                return
            }
            readyState = .closed
            for event in events {
                delegate?.dispatchEvent(event)
            }
            events.removeAll()
        }
    }
    fileprivate(set) var timestamp:TimeInterval = 0
    fileprivate var events:[Event] = []

    @discardableResult
    func doOutput(chunk:RTMPChunk) -> Int {
        let chunks:[[UInt8]] = chunk.split(chunkSizeS)
        for chunk in chunks {
            doOutput(bytes: chunk)
        }
        if (logger.isEnabledForLogLevel(.verbose)) {
            logger.verbose(chunk.description)
        }
        return chunk.message!.length
    }

    func connect(_ hostname:String, port:Int) {
        networkQueue.async {
            Foundation.Stream.getStreamsToHost(
                withName: hostname,
                port: port,
                inputStream: &self.inputStream,
                outputStream: &self.outputStream
            )
            self.initConnection()
        }
    }

    override func listen() {
        switch readyState {
        case .versionSent:
            if (inputBuffer.count < RTMPSocket.sigSize + 1) {
                break
            }
            let c2packet:ByteArray = ByteArray()
            c2packet
                .writeBytes(Array(inputBuffer[1...4]))
                .writeInt32(Int32(Date().timeIntervalSince1970 - timestamp))
                .writeBytes(Array(inputBuffer[9...RTMPSocket.sigSize]))
            doOutput(bytes: c2packet.bytes)
            inputBuffer = Array(inputBuffer[RTMPSocket.sigSize + 1..<inputBuffer.count])
            readyState = .ackSent
        case .ackSent:
            if (inputBuffer.count < RTMPSocket.sigSize) {
                break
            }
            inputBuffer.removeAll()
            readyState = .handshakeDone
        case .handshakeDone:
            if (inputBuffer.isEmpty){
                break
            }
            let bytes:[UInt8] = inputBuffer
            inputBuffer.removeAll()
            delegate?.listen(self, bytes: bytes)
        default:
            break
        }
    }

    override func initConnection() {
        readyState = .uninitialized
        timestamp = 0
        chunkSizeS = RTMPChunk.defaultSize
        chunkSizeC = RTMPChunk.defaultSize
        super.initConnection()
    }

    override func deinitConnection(_ disconnect:Bool) {
        if (disconnect) {
            let data:ASObject = (readyState == .handshakeDone) ?
                RTMPConnection.Code.ConnectClosed.data("") : RTMPConnection.Code.ConnectFailed.data("")
            events.append(Event(type: Event.RTMP_STATUS, bubbles: false, data: data))
        }
        readyState = .closing
        super.deinitConnection(disconnect)
    }

    override func didTimeout() {
        deinitConnection(false)
        delegate?.dispatchEventWith(Event.IO_ERROR, bubbles: false, data: nil)
        logger.warning("connection timedout")
    }
}
