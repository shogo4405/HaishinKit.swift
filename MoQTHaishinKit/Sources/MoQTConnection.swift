import Foundation

@available(iOS 16.0, macOS 13.0, *)
public actor MoQTConnection {
    public static let defaultPort = 4433
    /// The supported protocols are moqt.
    public static let supportedProtocols = ["moqt"]
    /// The supported protocol versions.
    public static let supportedVersions: [MoQTVersion] = [.draft07Exp2]
    /// The default a control request time out value (ms).
    public static let defaultRequestTimeout: UInt64 = 3000

    /// The error domain code.
    public enum Error: Swift.Error {
        /// An invalid internal stare.
        case invalidState
        /// The command isn’t supported.
        case unsupportedCommand(_ command: String)
        /// The connected operation timed out.
        case connectionTimedOut
        /// The general socket error.
        case socketErrorOccurred(_ error: any Swift.Error)
        /// The requested operation timed out.
        case requestTimedOut
        case unknownResponse
    }

    public let role: MoQTSetupRole
    /// The control message  request timeout value. Defaul value is 500 msec.
    public let requestTimeout: UInt64

    public var objectStream: AsyncStream<MoQTObject> {
        AsyncStream<MoQTObject> { continuation in
            self.objectStreamContinuation = continuation
        }
    }

    private var socket: MoQTSocket?
    private var inputBuffer = MoQTPayload()
    private var outputBuffer = MoQTPayload()
    private var datagramBuffer = MoQTPayload()
    private var continuation: CheckedContinuation<any MoQTMessage, any Swift.Error>?
    private var currentTrackAlias = 0
    private var currentSubscribeId = 0
    private var objectStreamContinuation: AsyncStream<MoQTObject>.Continuation?

    /// Creates a new connection.
    public init(_ role: MoQTSetupRole, requestTimeOut: UInt64 = MoQTConnection.defaultRequestTimeout) {
        self.role = .subscriber
        self.requestTimeout = requestTimeOut
    }

    /// Creates a two-way connection to an application on MoQT Server.
    public func connect(_ uri: String) async throws -> MoQTServerSetup {
        guard let uri = URL(string: uri), let scheme = uri.scheme, let host = uri.host, Self.supportedProtocols.contains(scheme) else {
            throw Error.unsupportedCommand(uri)
        }
        socket = .init()
        guard let socket else {
            throw Error.invalidState
        }
        do {
            try await socket.connect(host, port: uri.port ?? Self.defaultPort)
            Task {
                for await data in await socket.incoming {
                    try? await didReceiveMessage(data)
                }
            }
            Task {
                for await data in await socket.datagram {
                    await didReceiveDataStream(data)
                }
            }
            guard let serverSetup = try await send(MoQTClientSetup(supportedVersions: Self.supportedVersions, role: role, path: uri.path())) as? MoQTServerSetup else {
                throw Error.unknownResponse
            }
            return serverSetup
        } catch {
            logger.error(error)
            throw error
        }
    }

    public func annouce(_ namespace: [String], authInfo: String?) async throws -> Result<MoQTAnnounce.Ok, MoQTAnnounce.Error> {
        var subscribeParameters: [MoQTVersionSpecificParameter] = .init()
        if let authInfo {
            subscribeParameters.append(.init(key: .authorizationInfo, value: authInfo))
        }
        let message = MoQTAnnounce(trackNamespace: namespace, subscribeParameters: subscribeParameters)
        switch try await send(message) {
        case let result as MoQTAnnounce.Ok:
            return .success(result)
        case let result as MoQTAnnounce.Error:
            return .failure(result)
        default:
            throw Error.unknownResponse
        }
    }

    public func subscribe(_ namespace: [String], name: String, authInfo: String? = nil) async throws -> Result<MoQTSubscribe.Ok, MoQTSubscribe.Error> {
        defer {
            currentTrackAlias += 1
            currentSubscribeId += 1
        }
        var subscribeParameters: [MoQTVersionSpecificParameter] = .init()
        if let authInfo {
            subscribeParameters.append(.init(key: .authorizationInfo, value: authInfo))
        }
        let message = MoQTSubscribe(
            subscribeId: currentSubscribeId,
            trackAlias: currentTrackAlias,
            trackNamespace: namespace,
            trackName: name,
            subscribePriority: 0,
            groupOrder: .descending,
            filterType: .latestGroup,
            startGroup: nil,
            startObject: nil,
            endGroup: nil,
            endObject: nil,
            subscribeParameters: subscribeParameters
        )
        switch try await send(message) {
        case let result as MoQTSubscribe.Ok:
            return .success(result)
        case let result as MoQTSubscribe.Error:
            return .failure(result)
        default:
            throw Error.unknownResponse
        }
    }

    public func subscribeAnnouces(_ namespace: [String], authInfo: String? = nil) async throws -> Result<MoQTSubscribeAnnounces.Ok, MoQTSubscribeAnnounces.Error> {
        var subscribeParameters: [MoQTVersionSpecificParameter] = .init()
        if let authInfo {
            subscribeParameters.append(.init(key: .authorizationInfo, value: authInfo))
        }
        let message = MoQTSubscribeAnnounces(
            trackNamespacePrefix: namespace,
            parameters: subscribeParameters
        )
        switch try await send(message) {
        case let result as MoQTSubscribeAnnounces.Ok:
            return .success(result)
        case let result as MoQTSubscribeAnnounces.Error:
            return .failure(result)
        default:
            throw Error.unknownResponse
        }
    }

    /// Closes the connection from the server.
    public func close() async {
        await socket?.close()
    }

    public func send(_ objects: [MoQTObject], header: MoQTStreamHeaderSubgroup) async throws {
        var buffer = MoQTPayload()
        buffer.putData(try header.payload)
        for object in objects {
            buffer.putData(try object.payload)
        }
        buffer.position = 0
        await socket?.sendDatagram(buffer.data)
    }

    private func send(_ message: some MoQTMessage) async throws -> any MoQTMessage {
        let content = try message.payload
        outputBuffer.position = 0
        outputBuffer.putInt(message.type.rawValue)
        outputBuffer.putInt(content.count)
        outputBuffer.putData(content)
        return try await withCheckedThrowingContinuation { continutation in
            self.continuation = continutation
            Task {
                try? await Task.sleep(nanoseconds: requestTimeout * 1_000_000)
                self.continuation.map {
                    $0.resume(throwing: Error.requestTimedOut)
                }
                self.continuation = nil
            }
            Task {
                await socket?.send(outputBuffer.data)
            }
        }
    }

    private func didReceiveMessage(_ data: Data) async throws {
        print(data.bytes)
        logger.trace(data)
        inputBuffer.position = 0
        inputBuffer.putData(data)
        inputBuffer.position = 0
        let type = try inputBuffer.getInt()
        let length = try inputBuffer.getInt()
        let message = try MoQTMessageType(rawValue: type)?.makeMessage(&inputBuffer)
        if let message {
            logger.info(message)
            continuation?.resume(returning: message)
        } else {
            try inputBuffer.getData(length)
            continuation?.resume(throwing: MoQTMessageError.notImplemented)
        }
        continuation = nil
    }

    private func didReceiveDataStream(_ data: Data) async {
        do {
            datagramBuffer.position = 0
            datagramBuffer.putData(data)
            datagramBuffer.position = 0
            let type = try datagramBuffer.getInt()
            switch MoQTDataStreamType(rawValue: type) {
            case .streamHeaderSubgroup:
                let message = try MoQTStreamHeaderSubgroup(&datagramBuffer)
                while 0 < datagramBuffer.bytesAvailable {
                    objectStreamContinuation?.yield(try .init(&datagramBuffer))
                }
            default:
                break
            }
        } catch {
            logger.warn(error)
        }
    }
}
