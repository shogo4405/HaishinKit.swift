import Foundation
import HaishinKit
import Network

@available(iOS 16.0, macOS 13.0, tvOS 16.0, *)
final actor MoQTSocket {
    static let alpn = ["moq-00"]
    static let defaultWindowSizeC = Int(UInt8.max)

    enum Error: Swift.Error {
        case invalidState
        case endOfStream
        case connectionTimedOut
        case connectionNotEstablished(_ error: NWError?)
    }

    var incoming: AsyncStream<Data> {
        AsyncStream<Data> { continuation in
            self.incomingContinuation = continuation
        }
    }

    var datagram: AsyncStream<Data> {
        AsyncStream<Data> { continuation in
            self.datagramContinuation = continuation
        }
    }

    private var timeout: UInt64 = 15
    private var connected = false
    private var windowSizeC = MoQTSocket.defaultWindowSizeC
    private var totalBytesIn = 0
    private var queueBytesOut = 0
    private var totalBytesOut = 0
    private var connection: NWConnection? {
        didSet {
            connection?.stateUpdateHandler = { state in
                Task { await self.stateDidChange(to: state) }
            }
            connection?.viabilityUpdateHandler = { viability in
                Task { await self.viabilityDidChange(to: viability) }
            }
        }
    }
    private var options: NWProtocolQUIC.Options = .init()
    private var outputs: AsyncStream<Data>.Continuation?
    private var connectionGroup: NWConnectionGroup? {
        didSet {
            connectionGroup?.newConnectionHandler = { connection in
                Task { await self.newConnection(connection) }
            }
            oldValue?.newConnectionHandler = nil
            oldValue?.stateUpdateHandler = nil
        }
    }
    private var continuation: CheckedContinuation<Void, any Swift.Error>?
    private var qualityOfService: DispatchQoS = .userInitiated
    private var incomingContinuation: AsyncStream<Data>.Continuation? {
        didSet {
            if let connection, let incomingContinuation {
                receive(on: connection, continuation: incomingContinuation)
            }
        }
    }
    private var datagramContinuation: AsyncStream<Data>.Continuation?
    private lazy var networkQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.MoQSocket.network", qos: qualityOfService)

    func connect(_ name: String, port: Int) async throws {
        guard !connected else {
            throw Error.invalidState
        }
        totalBytesIn = 0
        totalBytesOut = 0
        queueBytesOut = 0
        do {
            let options = NWProtocolQUIC.Options(alpn: Self.alpn).verifySelfCert()
            let endpoint = NWEndpoint.hostPort(host: .init(name), port: .init(integerLiteral: NWEndpoint.Port.IntegerLiteralType(port)))
            connection = NWConnection(to: endpoint, using: NWParameters(quic: options))
            options.isDatagram = true
            connectionGroup = NWConnectionGroup(with: NWMultiplexGroup(to: endpoint), using: NWParameters(quic: options))
            try await withCheckedThrowingContinuation { (checkedContinuation: CheckedContinuation<Void, Swift.Error>) in
                self.continuation = checkedContinuation
                Task {
                    try? await Task.sleep(nanoseconds: timeout * 1_000_000_000)
                    guard let continuation else {
                        return
                    }
                    continuation.resume(throwing: Error.connectionTimedOut)
                    self.continuation = nil
                    close()
                }
                connection?.start(queue: networkQueue)
            }
        } catch {
            throw error
        }
    }

    func send(_ data: Data) {
        guard connected else {
            return
        }
        queueBytesOut += data.count
        outputs?.yield(data)
    }

    func sendDatagram(_ data: Data) {
        connectionGroup?.send(content: data) { _ in
        }
    }

    func close(_ error: NWError? = nil) {
        guard connection != nil else {
            return
        }
        if let continuation {
            continuation.resume(throwing: Error.connectionNotEstablished(error))
            self.continuation = nil
        }
        connected = false
        outputs = nil
        connection = nil
        continuation = nil
    }

    private func newConnection(_ connection: NWConnection) {
        receive(on: connection, continuation: datagramContinuation)
        connection.start(queue: networkQueue)
    }

    private nonisolated func receive(on connection: NWConnection, continuation: AsyncStream<Data>.Continuation?) {
        connection.receive(minimumIncompleteLength: 0, maximumLength: 65558) { content, _, _, _ in
            if let content {
                continuation?.yield(content)
                self.receive(on: connection, continuation: continuation)
            }
        }
    }

    private func stateDidChange(to state: NWConnection.State) {
        switch state {
        case .ready:
            logger.info("Connection is ready.")
            connected = true
            let (stream, continuation) = AsyncStream<Data>.makeStream()
            Task {
                for await data in stream where connected {
                    try await send(data)
                    totalBytesOut += data.count
                    queueBytesOut -= data.count
                }
            }
            self.outputs = continuation
            self.connectionGroup?.start(queue: networkQueue)
            self.continuation?.resume()
            self.continuation = nil
        case .waiting(let error):
            logger.warn("Connection waiting:", error)
            close(error)
        case .setup:
            logger.debug("Connection is setting up.")
        case .preparing:
            logger.debug("Connection is preparing.")
        case .failed(let error):
            logger.warn("Connection failed:", error)
            close(error)
        case .cancelled:
            logger.info("Connection cancelled.")
            close()
        @unknown default:
            logger.error("Unknown connection state.")
        }
    }

    private func viabilityDidChange(to viability: Bool) {
        logger.info("Connection viability changed to ", viability)
        if viability == false {
            close()
        }
    }

    private func send(_ data: Data) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            guard let connection else {
                continuation.resume(throwing: Error.invalidState)
                return
            }
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume()
            })
        }
    }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, *)
extension MoQTSocket: NetworkTransportReporter {
    // MARK: NetworkTransportReporter
    func makeNetworkMonitor() async -> NetworkMonitor {
        return .init(self)
    }

    func makeNetworkTransportReport() -> NetworkTransportReport {
        return .init(queueBytesOut: queueBytesOut, totalBytesIn: totalBytesIn, totalBytesOut: totalBytesOut)
    }
}
