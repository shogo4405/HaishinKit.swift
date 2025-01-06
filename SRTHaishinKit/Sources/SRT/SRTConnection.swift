import Combine
import Foundation
import HaishinKit
import libsrt

/// An actor that provides the interface to control a two-way SRT connection.
public actor SRTConnection: NetworkConnection {
    /// The error domain codes.
    public enum Error: Swift.Error {
        /// An invalid internal stare.
        case invalidState
        /// The uri isn’t supported.
        case unsupportedUri(_ uri: URL?)
        /// The fail to connect.
        case failedToConnect(_ message: String, reson: Int32)
    }

    /// The SRT Library version
    public static let version: String = SRT_VERSION_STRING
    /// The URI passed to the SRTConnection.connect() method.
    public private(set) var uri: URL?
    /// This instance connect to server(true) or not(false)
    @Published public private(set) var connected = false

    private var mode: SRTMode = .caller
    private var socket: SRTSocket?
    private var streams: [SRTStream] = []
    private var clients: [SRTSocket] = []
    private var networkMonitor: NetworkMonitor?

    /// The SRT's performance data.
    public var performanceData: SRTPerformanceData? {
        get async {
            guard let socket else {
                return nil
            }
            _ = await socket.bstats()
            return await SRTPerformanceData(mon: socket.perf)
        }
    }

    /// Creates an object.
    public init() {
        srt_startup()
    }

    deinit {
        streams.removeAll()
        srt_cleanup()
    }

    /// Open a two-way connection to an application on SRT Server.
    public func open(_ uri: URL?, mode: SRTMode = .caller) async throws {
        guard let uri = uri, let scheme = uri.scheme, let host = uri.host, let port = uri.port, scheme == "srt" else {
            throw Error.unsupportedUri(uri)
        }
        do {
            let options = SRTSocketOption.from(uri: uri)
            let addr = sockaddr_in(mode.host(host), port: UInt16(port))
            let socket = SRTSocket()
            self.socket = socket
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Swift.Error>) in
                Task {
                    do {
                        try await socket.open(addr, mode: mode, options: options)
                        self.uri = uri
                        connected = await socket.status == SRTS_CONNECTED
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            self.mode = mode
            switch mode {
            case .caller:
                Task {
                    let networkMonitor = await socket.makeNetworkMonitor()
                    self.networkMonitor = networkMonitor
                    await networkMonitor.startRunning()
                    for await event in await networkMonitor.event {
                        for stream in streams {
                            await stream.dispatch(event)
                        }
                    }
                }
            case .listener:
                Task {
                    for await client in await socket.accept {
                        connected = true
                        clients.append(client)
                    }
                }
            }
        } catch {
            throw error
        }
    }

    /// Closes the connection from the server.
    public func close() async throws {
        guard connected else {
            throw Error.invalidState
        }
        await networkMonitor?.stopRunning()
        for client in clients {
            await client.close()
        }
        clients.removeAll()
        for stream in streams {
            await stream.close()
        }
        await socket?.close()
        connected = false
    }

    func send(_ data: Data) async {
        switch mode {
        case .caller:
            await socket?.send(data)
        case .listener:
            await clients.first?.send(data)
        }
    }

    func recv() {
        Task {
            switch mode {
            case .caller:
                guard let socket else {
                    return
                }
                for await data in await socket.inputs {
                    await streams.first?.doInput(data)
                }
            case .listener:
                guard let socket = clients.first else {
                    return
                }
                for await data in await socket.inputs {
                    await streams.first?.doInput(data)
                }
            }
        }
    }

    func addStream(_ stream: SRTStream) {
        guard !streams.contains(where: { $0 === stream }) else {
            return
        }
        streams.append(stream)
    }

    func removeStream(_ stream: SRTStream) {
        if let index = streams.firstIndex(where: { $0 === stream }) {
            streams.remove(at: index)
        }
    }

    private func sockaddr_in(_ host: String, port: UInt16) -> sockaddr_in {
        var addr: sockaddr_in = .init()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = CFSwapInt16BigToHost(UInt16(port))
        if inet_pton(AF_INET, host, &addr.sin_addr) == 1 {
            return addr
        }
        guard let hostent = gethostbyname(host), hostent.pointee.h_addrtype == AF_INET else {
            return addr
        }
        addr.sin_addr = UnsafeRawPointer(hostent.pointee.h_addr_list[0]!).assumingMemoryBound(to: in_addr.self).pointee
        return addr
    }
}
