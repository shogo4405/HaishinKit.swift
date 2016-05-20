import Foundation

// MARK: - RTMPSocketDelegate
protocol RTMPSocketDelegate: IEventDispatcher {
    func listen(socket:RTMPSocket, bytes:[UInt8])
    func didSetReadyState(socket:RTMPSocket, readyState:RTMPSocket.ReadyState)
}

// MARK: - RTMPSocket
final class RTMPSocket: NetSocket {

    enum ReadyState: UInt8 {
        case Uninitialized = 0
        case VersionSent   = 1
        case AckSent       = 2
        case HandshakeDone = 3
        case Closing       = 4
        case Closed        = 5
    }

    static let sigSize:Int = 1536
    static let protocolVersion:UInt8 = 3
    static let defaultBufferSize:Int = 1024

    var readyState:ReadyState = .Uninitialized {
        didSet {
            delegate?.didSetReadyState(self, readyState: readyState)
        }
    }

    var chunkSizeC:Int = RTMPChunk.defaultSize
    var chunkSizeS:Int = RTMPChunk.defaultSize
    var objectEncoding:UInt8 = RTMPConnection.defaultObjectEncoding
    weak var delegate:RTMPSocketDelegate? = nil
    private(set) var timestamp:NSTimeInterval = 0

    func doOutput(chunk chunk:RTMPChunk) {
        logger.verbose(chunk.description)
        let chunks:[[UInt8]] = chunk.split(chunkSizeS)
        for chunk in chunks {
            doOutput(bytes: chunk)
        }
    }

    func connect(hostname:String, port:Int) {
        dispatch_async(networkQueue) {
            NSStream.getStreamsToHostWithName(
                hostname,
                port: port,
                inputStream: &self.inputStream,
                outputStream: &self.outputStream
            )
            self.initConnection()
        }
    }

    override func didOpenCompleted() {
        timestamp = NSDate().timeIntervalSince1970
        let c1packet:ByteArray = ByteArray()
        c1packet.writeInt32(Int32(timestamp))
        c1packet.writeBytes([0x00, 0x00, 0x00, 0x00])
        for _ in 0..<RTMPSocket.sigSize - 8 {
            c1packet.writeUInt8(UInt8(arc4random_uniform(0xff)))
        }
        doOutput(bytes: [RTMPSocket.protocolVersion])
        doOutput(bytes: c1packet.bytes)
        readyState = .VersionSent
    }

    override func listen() {
        switch readyState {
        case .VersionSent:
            if (inputBuffer.count < RTMPSocket.sigSize + 1) {
                break
            }
            let c2packet:ByteArray = ByteArray()
            c2packet.writeBytes(Array(inputBuffer[1...4]))
            c2packet.writeInt32(Int32(NSDate().timeIntervalSince1970 - timestamp))
            c2packet.writeBytes(Array(inputBuffer[9...RTMPSocket.sigSize]))
            doOutput(bytes: c2packet.bytes)
            inputBuffer = Array(inputBuffer[RTMPSocket.sigSize + 1..<inputBuffer.count])
            readyState = .AckSent
        case .AckSent:
            if (inputBuffer.count < RTMPSocket.sigSize) {
                break
            }
            inputBuffer.removeAll()
            readyState = .HandshakeDone
        case .HandshakeDone:
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
        readyState = .Uninitialized
        timestamp = 0
        chunkSizeS = RTMPChunk.defaultSize
        chunkSizeC = RTMPChunk.defaultSize
        super.initConnection()
    }

    override func deinitConnection(disconnect:Bool) {
        var data:ASObject? = nil
        if (disconnect) {
            data = (readyState == .HandshakeDone) ?
                RTMPConnection.Code.ConnectClosed.data("") : RTMPConnection.Code.ConnectFailed.data("")
        }
        readyState = .Closing
        super.deinitConnection(disconnect)
        readyState = .Closed
        if let data:ASObject = data {
            delegate?.dispatchEventWith(Event.RTMP_STATUS, bubbles: false, data: data)
        }
    }
}

