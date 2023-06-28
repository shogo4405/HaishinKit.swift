import Foundation
#if canImport(Network)
import Network
#endif

@available(iOS 12.0, macOS 10.14, tvOS 12.0, *)
final class RTMPNWSocket: RTMPSocketCompatible {
    static let defaultWindowSizeC = Int(UInt8.max)

    var timestamp: TimeInterval = 0.0
    var chunkSizeC: Int = RTMPChunk.defaultSize
    var chunkSizeS: Int = RTMPChunk.defaultSize
    var windowSizeC = RTMPNWSocket.defaultWindowSizeC
    var timeout: Int = NetSocket.defaultTimeout
    var readyState: RTMPSocketReadyState = .uninitialized {
        didSet {
            delegate?.socket(self, readyState: readyState)
        }
    }
    var outputBufferSize: Int = RTMPNWSocket.defaultWindowSizeC
    var securityLevel: StreamSocketSecurityLevel = .none {
        didSet {
            switch securityLevel {
            case .ssLv2, .ssLv3, .tlSv1, .negotiatedSSL:
                parameters = .tls
            default:
                parameters = .tcp
            }
        }
    }
    var qualityOfService: DispatchQoS = .userInitiated
    var inputBuffer = Data()
    weak var delegate: (any RTMPSocketDelegate)?

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
            oldValue?.cancel()
            if connection == nil {
                connected = false
                readyState = .closed
            }
        }
    }
    private var parameters: NWParameters = .tcp
    private lazy var inputQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.RTMPNWSocket.input", qos: qualityOfService)
    private lazy var outputQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.RTMPNWSocket.output", qos: qualityOfService)
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
        guard let connection else {
            return
        }
        if isDisconnected {
            let data: ASObject = (readyState == .handshakeDone) ?
                RTMPConnection.Code.connectClosed.data("") : RTMPConnection.Code.connectFailed.data("")
            events.append(Event(type: .rtmpStatus, bubbles: false, data: data))
        }
        readyState = .closing
        if connection.state == .ready {
            outputQueue.async {
                let completion: NWConnection.SendCompletion = .contentProcessed { (_: Error?) in
                    self.connection = nil
                }
                connection.send(content: nil, contentContext: .finalMessage, isComplete: true, completion: completion)
            }
        } else {
            self.connection = nil
        }
        timeoutHandler?.cancel()
    }

    @discardableResult
    func doOutput(chunk: RTMPChunk) -> Int {
        let chunks: [Data] = chunk.split(chunkSizeS)
        for i in 0..<chunks.count - 1 {
            doOutput(data: chunks[i])
        }
        doOutput(data: chunks.last!)
        if logger.isEnabledFor(level: .trace) {
            logger.trace(chunk)
        }
        return chunk.message!.length
    }

    @discardableResult
    func doOutput(data: Data) -> Int {
        queueBytesOut.mutate { $0 = Int64(data.count) }
        outputQueue.async {
            let sendCompletion = NWConnection.SendCompletion.contentProcessed { error in
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
            logger.info("Connection is ready.")
            timeoutHandler?.cancel()
            connected = true
        case .waiting(let error):
            logger.warn("Connection waiting:", error)
            close(isDisconnected: true)
        case .setup:
            logger.debug("Connection is setting up.")
        case .preparing:
            logger.debug("Connection is preparing.")
        case .failed(let error):
            logger.warn("Connection failed:", error)
            close(isDisconnected: true)
        case .cancelled:
            logger.info("Connection cancelled.")
            close(isDisconnected: true)
        @unknown default:
            logger.error("Unknown connection state.")
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
        case .handshakeDone, .closing:
            if inputBuffer.isEmpty {
                break
            }
            let bytes: Data = inputBuffer
            inputBuffer.removeAll()
            delegate?.socket(self, data: bytes)
        default:
            break
        }
    }
}
