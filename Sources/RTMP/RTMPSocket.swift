import Foundation

protocol RTMPSocketCompatible: class {
    var timeout: Int64 { get set }
    var connected: Bool { get }
    var timestamp: TimeInterval { get }
    var chunkSizeC: Int { get set }
    var chunkSizeS: Int { get set }
    var totalBytesIn: Int64 { get }
    var totalBytesOut: Int64 { get }
    var queueBytesOut: Int64 { get }
    var inputBuffer: Data { get set }
    var securityLevel: StreamSocketSecurityLevel { get set }
    var delegate: RTMPSocketDelegate? { get set }

    @discardableResult
    func doOutput(chunk: RTMPChunk, locked: UnsafeMutablePointer<UInt32>?) -> Int
    func close(isDisconnected: Bool)
    func connect(withName: String, port: Int)
    func deinitConnection(isDisconnected: Bool)
}

// MARK: -
protocol RTMPSocketDelegate: IEventDispatcher {
    func listen(_ data: Data)
    func didSetReadyState(_ readyState: RTMPSocket.ReadyState)
    func didSetTotalBytesIn(_ totalBytesIn: Int64)
}

// MARK: -
final class RTMPSocket: NetSocket, RTMPSocketCompatible {
    enum ReadyState: UInt8 {
        case uninitialized = 0
        case versionSent = 1
        case ackSent = 2
        case handshakeDone = 3
        case closing = 4
        case closed = 5
    }

    var readyState: ReadyState = .uninitialized {
        didSet {
            delegate?.didSetReadyState(readyState)
        }
    }
    var timestamp: TimeInterval {
        return handshake.timestamp
    }
    var chunkSizeC: Int = RTMPChunk.defaultSize
    var chunkSizeS: Int = RTMPChunk.defaultSize
    weak var delegate: RTMPSocketDelegate?
    override var totalBytesIn: Int64 {
        didSet {
            delegate?.didSetTotalBytesIn(totalBytesIn)
        }
    }

    override var connected: Bool {
        didSet {
            if connected {
                doOutput(data: handshake.c0c1packet)
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

    private var events: [Event] = []
    private var handshake = RTMPHandshake()

    @discardableResult
    func doOutput(chunk: RTMPChunk, locked: UnsafeMutablePointer<UInt32>? = nil) -> Int {
        let chunks: [Data] = chunk.split(chunkSizeS)
        for i in 0..<chunks.count - 1 {
            doOutput(data: chunks[i])
        }
        doOutput(data: chunks.last!, locked: locked)
        if logger.isEnabledFor(level: .trace) {
            logger.trace(chunk)
        }
        return chunk.message!.length
    }

    override func connect(withName: String, port: Int) {
        inputQueue.async {
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
            if inputBuffer.count < RTMPHandshake.sigSize + 1 {
                break
            }
            doOutput(data: handshake.c2packet(inputBuffer))
            inputBuffer.removeSubrange(0...RTMPHandshake.sigSize)
            readyState = .ackSent
            if RTMPHandshake.sigSize <= inputBuffer.count {
                listen()
            }
        case .ackSent:
            if inputBuffer.count < RTMPHandshake.sigSize {
                break
            }
            inputBuffer.removeAll()
            readyState = .handshakeDone
        case .handshakeDone:
            if inputBuffer.isEmpty {
                break
            }
            let bytes: Data = inputBuffer
            inputBuffer.removeAll()
            delegate?.listen(bytes)
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

    override func deinitConnection(isDisconnected: Bool) {
        if isDisconnected {
            let data: ASObject = (readyState == .handshakeDone) ?
                RTMPConnection.Code.connectClosed.data("") : RTMPConnection.Code.connectFailed.data("")
            events.append(Event(type: Event.RTMP_STATUS, bubbles: false, data: data))
        }
        readyState = .closing
        super.deinitConnection(isDisconnected: isDisconnected)
    }

    override func didTimeout() {
        deinitConnection(isDisconnected: false)
        delegate?.dispatch(Event.IO_ERROR, bubbles: false, data: nil)
        logger.warn("connection timedout")
    }
}
