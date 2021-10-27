import Foundation
#if canImport(Network)
    import Network
#endif

@available(iOS 12.0, macOS 10.14, tvOS 12.0, *)
final class RTMPNWSocket: RTMPSocketCompatible {
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
    var securityLevel: StreamSocketSecurityLevel = .none
    var qualityOfService: DispatchQoS = .default
    var inputBuffer = Data()
    weak var delegate: RTMPSocketDelegate?

    private(set) var queueBytesOut: Atomic<Int64> = .init(0)
    private(set) var totalBytesIn: Atomic<Int64> = .init(0)
    private(set) var totalBytesOut: Atomic<Int64> = .init(0)
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
    private var handshake = RTMPHandshake()
    private var connection: NWConnection? {
        didSet {
            oldValue?.stateUpdateHandler = nil
            oldValue?.forceCancel()
            if connection == nil {
                connected = false
            }
        }
    }
    private var parameters: NWParameters = .tcp
    private lazy var inputQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.NWSocket.input", qos: qualityOfService)
    private lazy var outputQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.NWSocket.output", qos: qualityOfService)
    private var timeoutHandler: DispatchWorkItem?

    func connect(withName: String, port: Int) {
        handshake.clear()
        readyState = .uninitialized
        chunkSizeS = RTMPChunk.defaultSize
        chunkSizeC = RTMPChunk.defaultSize
        totalBytesIn.mutate { $0 = 0 }
        totalBytesOut.mutate { $0 = 0 }
        queueBytesOut.mutate { $0 = 0 }
        inputBuffer.removeAll(keepingCapacity: false)
        connection = NWConnection(to: NWEndpoint.hostPort(host: .init(withName), port: .init(integerLiteral: NWEndpoint.Port.IntegerLiteralType(port))), using: parameters)
        connection?.stateUpdateHandler = stateDidChange(to:)
        connection?.start(queue: inputQueue)
        if let connection = connection {
            receive(on: connection)
        }
        if 0 < timeout {
            let newTimeoutHandler = DispatchWorkItem { [weak self] in
                guard let self = self, self.timeoutHandler?.isCancelled == false else {
                    return
                }
                self.didTimeout()
            }
            timeoutHandler = newTimeoutHandler
            DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + .seconds(timeout), execute: newTimeoutHandler)
        }
    }

    func close(isDisconnected: Bool) {
        guard connection != nil else {
            return
        }
        if isDisconnected {
            let data: ASObject = (readyState == .handshakeDone) ?
                RTMPConnection.Code.connectClosed.data("") : RTMPConnection.Code.connectFailed.data("")
            events.append(Event(type: .rtmpStatus, bubbles: false, data: data))
        }
        readyState = .closing
        timeoutHandler?.cancel()
        connection = nil
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
        queueBytesOut.mutate { $0 = Int64(data.count) }
        outputQueue.async {
            let sendCompletion = NWConnection.SendCompletion.contentProcessed { error in
                defer {
                    if locked != nil {
                        OSAtomicAnd32Barrier(0, locked!)
                    }
                }
                guard self.connected else {
                    return
                }
                if error != nil {
                    self.close(isDisconnected: true)
                    return
                }
                self.totalBytesOut.mutate { $0 += Int64(data.count) }
                self.queueBytesOut.mutate { $0 -= Int64(data.count) }
            }
            self.connection?.send(content: data, completion: sendCompletion)
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
            timeoutHandler?.cancel()
            connected = true
        case .failed:
            close(isDisconnected: true)
        case .cancelled:
            close(isDisconnected: true)
        default:
            break
        }
    }

    private func receive(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 0, maximumLength: windowSizeC) { [weak self] data, _, _, _ in
            guard let self = self, let data = data, self.connected else {
                return
            }
            self.inputBuffer.append(data)
            self.totalBytesIn.mutate { $0 += Int64(data.count) }
            self.listen()
            self.receive(on: connection)
        }
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
