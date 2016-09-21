import Foundation

protocol RTMPSocketCompatible: class {
    var timeout:Int64 { get set }
    var timestamp:TimeInterval { get }
    var chunkSizeC:Int { get set }
    var chunkSizeS:Int { get set }
    var totalBytesIn:Int64 { get }
    var totalBytesOut:Int64 { get }
    var inputBuffer:[UInt8] { get set }
    var securityLevel:StreamSocketSecurityLevel { get set }
    var objectEncoding:UInt8 { get set }
    weak var delegate:RTMPSocketDelegate? { get set }

    @discardableResult
    func doOutput(chunk:RTMPChunk) -> Int
    func close(isDisconnected:Bool)
    func connect(withName:String, port:Int)
    func deinitConnection(isDisconnected:Bool)
}

// MARK: -
protocol RTMPSocketDelegate: IEventDispatcher {
    func listen(bytes:[UInt8])
    func didSet(readyState:RTMPSocket.ReadyState)
}

// MARK: -
final class RTMPSocket: NetSocket, RTMPSocketCompatible {

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
            delegate?.didSet(readyState: readyState)
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
                delegate?.dispatch(event: event)
            }
            events.removeAll()
        }
    }
    private(set) var timestamp:TimeInterval = 0
    private var events:[Event] = []

    @discardableResult
    func doOutput(chunk:RTMPChunk) -> Int {
        let chunks:[[UInt8]] = chunk.split(chunkSizeS)
        for chunk in chunks {
            doOutput(bytes: chunk)
        }
        if (logger.isEnabledFor(level: .verbose)) {
            logger.verbose(chunk.description)
        }
        return chunk.message!.length
    }

    func connect(withName:String, port:Int) {
        networkQueue.async {
            Stream.getStreamsToHost(
                withName: withName,
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
            delegate?.listen(bytes: bytes)
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

    override func deinitConnection(isDisconnected:Bool) {
        if (isDisconnected) {
            let data:ASObject = (readyState == .handshakeDone) ?
                RTMPConnection.Code.connectClosed.data("") : RTMPConnection.Code.connectFailed.data("")
            events.append(Event(type: Event.RTMP_STATUS, bubbles: false, data: data))
        }
        readyState = .closing
        super.deinitConnection(isDisconnected: isDisconnected)
    }

    override func didTimeout() {
        deinitConnection(isDisconnected: false)
        delegate?.dispatch(Event.IO_ERROR, bubbles: false, data: nil)
        logger.warning("connection timedout")
    }
}
