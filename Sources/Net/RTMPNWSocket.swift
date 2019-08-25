import Foundation
#if canImport(Network)
    import Network
#endif

@available(iOS 12.0, macOS 10.14, tvOS 12.0, *)
class RTMPNWSocket: RTMPSocketCompatible {
    var timestamp: TimeInterval = 0.0
    var chunkSizeC: Int = RTMPChunk.defaultSize
    var chunkSizeS: Int = RTMPChunk.defaultSize
    var windowSizeC = Int(UInt8.max)
    var timeout: Int = NetSocket.defaultTimeout
    var readyState: RTMPSocketReadyState = .uninitialized {
        didSet {
            delegate?.didSetReadyState(readyState)
        }
    }
    weak var delegate: RTMPSocketDelegate?
    private(set) var queueBytesOut: Int64 = 0
    private(set) var totalBytesIn: Int64 = 0
    private(set) var totalBytesOut: Int64 = 0
    private(set) var connected = false {
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

    var securityLevel: StreamSocketSecurityLevel = .none
    var qualityOfService: DispatchQoS = .default
    var inputBuffer = Data()

    private var conn: NWConnection?
    private var handshake = RTMPHandshake()
    private var parameters: NWParameters = .tcp
    private lazy var queue = DispatchQueue(label: "com.haishinkit.HaishinKit.NWSocket.queue", qos: qualityOfService)
    private lazy var inputQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.NWSocket.input", qos: qualityOfService)
    private lazy var outputQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.NWSocket.output", qos: qualityOfService)
    private lazy var timeoutHandler = DispatchWorkItem { [weak self] in
        self?.didTimeout()
    }

    deinit {
        conn?.forceCancel()
        conn = nil
    }

    func connect(withName: String, port: Int) {
        conn = NWConnection(to: NWEndpoint.hostPort(host: .init(withName), port: .init(integerLiteral: NWEndpoint.Port.IntegerLiteralType(port))), using: parameters)
        conn?.stateUpdateHandler = self.stateDidChange(to:)
        conn?.start(queue: queue)
        receiveLoop(conn!)
        if 0 < timeout {
            outputQueue.asyncAfter(deadline: .now() + .seconds(timeout), execute: timeoutHandler)
        }
    }

    func close(isDisconnected: Bool) {
        timeoutHandler.cancel()
        outputQueue = .init(label: outputQueue.label, qos: qualityOfService)
        inputBuffer.removeAll()
        conn?.cancel()
        conn = nil
        connected = false
    }

    func deinitConnection(isDisconnected: Bool) {
    }

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

    @discardableResult
    func doOutput(data: Data, locked: UnsafeMutablePointer<UInt32>? = nil) -> Int {
        OSAtomicAdd64(Int64(data.count), &queueBytesOut)
        outputQueue.async {
            let sendCompletion = NWConnection.SendCompletion.contentProcessed { error in
                if error != nil {
                    self.close(isDisconnected: true)
                    return
                }
                self.totalBytesOut += Int64(data.count)
                OSAtomicAdd64(Int64(data.count), &self.queueBytesOut)
                if locked != nil {
                    OSAtomicAnd32Barrier(0, locked!)
                }
            }
            self.conn?.send(content: data, completion: sendCompletion)
        }
        return data.count
    }

    func setProperty(_ value: Any?, forKey: String) {
        switch forKey {
        case "parameters":
            guard let value = value as? NWParameters else {
                return
            }
            parameters = value
        default:
            break
        }
    }

    private func stateDidChange(to state: NWConnection.State) {
        switch state {
        case .ready:
            timeoutHandler.cancel()
            connected = true
        case .failed:
            close(isDisconnected: true)
        case .cancelled:
            close(isDisconnected: true)
        default:
            break
        }
    }

    private func receiveLoop(_ conn: NWConnection) {
        let receiveCompletion = { [weak self] (_ data: Data?, _ ctx: NWConnection.ContentContext?, _ isComplete: Bool, _ error: NWError?) -> Void in
            guard let me = self else {
                return
            }
            me.receive(data, ctx, isComplete, error)
            if me.connected {
                me.inputQueue.async { [weak me] () -> Void in
                    me?.receiveLoop(conn)
                }
            }
        }
        inputQueue.async { [weak self] () -> Void in
            guard let windowSizeC = self?.windowSizeC else {
                return
            }
            conn.receive(minimumIncompleteLength: 0, maximumLength: windowSizeC, completion: receiveCompletion)
        }
    }

    private func receive(_ data: Data?, _ ctx: NWConnection.ContentContext?, _ isComplete: Bool, _ error: NWError?) {
        if error != nil {
            close(isDisconnected: true)
            return
        }
        guard let d = data else {
            return
        }
        inputBuffer.append(d)
        totalBytesIn += Int64(d.count)

        listen()
    }

    private func listen() {
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
}
