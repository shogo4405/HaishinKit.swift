import Foundation

protocol RTMPSocketCompatible: class {
    var timeout:Int64 { get set }
    var timestamp:TimeInterval { get }
    var chunkSizeC:Int { get set }
    var chunkSizeS:Int { get set }
    var totalBytesIn:Int64 { get }
    var totalBytesOut:Int64 { get }
    var queueBytesOut:Int64 { get }
    var inputBuffer:[UInt8] { get set }
    var securityLevel:StreamSocketSecurityLevel { get set }
    weak var delegate:RTMPSocketDelegate? { get set }

    @discardableResult
    func doOutput(chunk:RTMPChunk, locked:UnsafeMutablePointer<UInt32>?) -> Int
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
    static let defaultBufferSize:Int = 1024

    enum ReadyState: UInt8 {
        case uninitialized = 0
        case versionSent   = 1
        case ackSent       = 2
        case handshakeDone = 3
        case closing       = 4
        case closed        = 5
    }

    var readyState:ReadyState = .uninitialized {
        didSet {
            delegate?.didSet(readyState: readyState)
        }
    }
    var timestamp:TimeInterval {
        return handshake.timestamp
    }
    var chunkSizeC:Int = RTMPChunk.defaultSize
    var chunkSizeS:Int = RTMPChunk.defaultSize
    weak var delegate:RTMPSocketDelegate? = nil

    override var connected:Bool {
        didSet {
            if (connected) {
                doOutput(bytes: handshake.c0c1packet)
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

    private var events:[Event] = []
    private var handshake:RTMPHandshake = RTMPHandshake()

    @discardableResult
    func doOutput(chunk:RTMPChunk, locked:UnsafeMutablePointer<UInt32>? = nil) -> Int {
        let chunks:[[UInt8]] = chunk.split(chunkSizeS)
        for i in 0..<chunks.count - 1 {
            doOutput(bytes: chunks[i])
        }
        doOutput(bytes: chunks.last!, locked: locked)
        if (logger.isEnabledFor(level: .verbose)) {
            logger.verbose(chunk)
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
            if (inputBuffer.count < RTMPHandshake.sigSize + 1) {
                break
            }
            doOutput(bytes: handshake.c2packet(inputBuffer))
            inputBuffer = Array(inputBuffer[RTMPHandshake.sigSize + 1..<inputBuffer.count])
            readyState = .ackSent
        case .ackSent:
            if (inputBuffer.count < RTMPHandshake.sigSize) {
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
        handshake.clear()
        readyState = .uninitialized
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
