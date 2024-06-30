import Foundation
import Network

final class RTMPSocket {
    static let defaultWindowSizeC = Int(UInt8.max)

    enum Error: Swift.Error {
        case noViability
    }

    var timestamp: TimeInterval = 0.0
    var windowSizeC = RTMPSocket.defaultWindowSizeC
    var qualityOfService: DispatchQoS = .userInitiated
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
    private var parameters: NWParameters = .tcp
    private var connection: NWConnection? {
        didSet {
            oldValue?.viabilityUpdateHandler = nil
            oldValue?.stateUpdateHandler = nil
            oldValue?.forceCancel()
        }
    }
    private lazy var networkQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.RTMPSocket.network", qos: qualityOfService)

    func connect(_ name: String, port: Int) async throws -> AsyncStream<Data> {
        let connection = NWConnection(to: NWEndpoint.hostPort(host: .init(name), port: .init(integerLiteral: NWEndpoint.Port.IntegerLiteralType(port))), using: parameters)
        self.connection = connection
        return try await withCheckedThrowingContinuation { continuation in
            let (stream, cont) = AsyncStream<Data>.makeStream()
            connection.receive(minimumIncompleteLength: 0, maximumLength: windowSizeC) { content, _, _, error in
                if let content {
                    cont.yield(content)
                    return
                }
                if error != nil {
                    cont.finish()
                    return
                }
            }
            connection.viabilityUpdateHandler = { viability in
                defer {
                    connection.viabilityUpdateHandler = nil
                }
                guard viability else {
                    continuation.resume(throwing: Error.noViability)
                    return
                }
                continuation.resume(returning: stream)
            }
            connection.start(queue: networkQueue)
        }
    }

    func send(_ data: Data) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            connection?.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume()
            })
        }
    }

    func close() {
        connection = nil
    }
}
