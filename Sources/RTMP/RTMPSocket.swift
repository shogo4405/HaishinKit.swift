import Foundation
#if canImport(Network)
    import Network
#endif

protocol RTMPSocketCompatible: class {
    var timeout: Int { get set }
    var delegate: RTMPSocketDelegate? { get set }
    var connected: Bool { get }
    var timestamp: TimeInterval { get }
    var chunkSizeC: Int { get set }
    var chunkSizeS: Int { get set }
    var inputBuffer: Data { get set }
    var totalBytesIn: Int64 { get }
    var totalBytesOut: Int64 { get }
    var queueBytesOut: Int64 { get }
    var securityLevel: StreamSocketSecurityLevel { get set }
    var qualityOfService: DispatchQoS { get set }

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
final class RTMPSocket: RTMPSocketCompatible {
    enum ReadyState: UInt8 {
        case uninitialized = 0
        case versionSent = 1
        case ackSent = 2
        case handshakeDone = 3
        case closing = 4
        case closed = 5
    }

    var inputBuffer: Data {
        get { return socket.inputBuffer }
        set { socket.inputBuffer = newValue }
    }

    var timeout: Int {
        get { return socket.timeout }
        set { socket.timeout = newValue }
    }

    var connected: Bool {
        return socket.connected
    }

    var totalBytesIn: Int64 {
        return socket.totalBytesIn
    }

    var totalBytesOut: Int64 {
        return socket.totalBytesOut
    }

    var queueBytesOut: Int64 {
        return socket.queueBytesOut
    }

    var securityLevel: StreamSocketSecurityLevel {
        get { return socket.securityLevel }
        set { socket.securityLevel = newValue }
    }

    var qualityOfService: DispatchQoS {
        get { return socket.qualityOfService }
        set { socket.qualityOfService = newValue }
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

    private var events: [Event] = []
    private var handshake = RTMPHandshake()
    private var socket: NetSocketCompatible

    convenience init() {
        self.init(NetSocket())
    }

    @available(iOS 12.0, macOS 10.14, tvOS 12, *)
    convenience init(_ nwParams: NWParameters) {
        let nwSocket = NWSocket(nwParams)
        self.init(nwSocket)
    }

    private init(_ socket: NetSocketCompatible) {
        self.socket = socket
        self.socket.timeoutHandler = didTimeout
        self.socket.inputHandler = didInputData
        self.socket.didSetTotalBytesIn = didSetTotalBytesIn
        self.socket.didSetTotalBytesOut = didSetTotalBytesOut
        self.socket.didSetConnected = didSetConnected
    }

    func didSetTotalBytesIn(_ totalbytesIn: Int64) {
        delegate?.didSetTotalBytesIn(totalbytesIn)
    }

    func didSetTotalBytesOut(_ totalBytesOut: Int64) {
    }

    func didSetConnected(_ connected: Bool) {
        if connected {
            socket.doOutput(data: handshake.c0c1packet, locked: nil)
            readyState = .versionSent
            return
        }
        readyState = .closed
        for event in events {
            delegate?.dispatch(event: event)
        }
        events.removeAll()
    }

    func connect(withName: String, port: Int) {
        socket.connect(withName: withName, port: port)
        handshake.clear()
        readyState = .uninitialized
        chunkSizeS = RTMPChunk.defaultSize
        chunkSizeC = RTMPChunk.defaultSize
    }

    func close(isDisconnected: Bool) {
        socket.close(isDisconnected: isDisconnected)
    }

    @discardableResult
    func doOutput(chunk: RTMPChunk, locked: UnsafeMutablePointer<UInt32>? = nil) -> Int {
        let chunks: [Data] = chunk.split(chunkSizeS)
        for i in 0..<chunks.count - 1 {
            socket.doOutput(data: chunks[i], locked: nil)
        }
        socket.doOutput(data: chunks.last!, locked: locked)
        if logger.isEnabledFor(level: .trace) {
            logger.trace(chunk)
        }
        return chunk.message!.length
    }

    func didInputData() {
        switch readyState {
        case .versionSent:
            if socket.inputBuffer.count < RTMPHandshake.sigSize + 1 {
                break
            }
            socket.doOutput(data: handshake.c2packet(socket.inputBuffer), locked: nil)
            socket.inputBuffer.removeSubrange(0...RTMPHandshake.sigSize)
            readyState = .ackSent
            if RTMPHandshake.sigSize <= socket.inputBuffer.count {
                didInputData()
            }
        case .ackSent:
            if socket.inputBuffer.count < RTMPHandshake.sigSize {
                break
            }
            socket.inputBuffer.removeAll()
            readyState = .handshakeDone
        case .handshakeDone:
            if socket.inputBuffer.isEmpty {
                break
            }
            let bytes: Data = socket.inputBuffer
            socket.inputBuffer.removeAll()
            delegate?.listen(bytes)
        default:
            break
        }
    }

    func deinitConnection(isDisconnected: Bool) {
        if isDisconnected {
            let data: ASObject = (readyState == .handshakeDone) ?
                RTMPConnection.Code.connectClosed.data("") : RTMPConnection.Code.connectFailed.data("")
            events.append(Event(type: Event.RTMP_STATUS, bubbles: false, data: data))
        }
        readyState = .closing
        socket.deinitConnection(isDisconnected: isDisconnected)
    }

    func didTimeout() {
        deinitConnection(isDisconnected: false)
        delegate?.dispatch(Event.IO_ERROR, bubbles: false, data: nil)
        logger.warn("connection timedout")
    }
}
