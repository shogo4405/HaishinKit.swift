import Foundation
import HaishinKit
import libsrt
import Logboard

final actor SRTSocket {
    static let payloadSize: Int = 1316

    enum Error: Swift.Error {
        case notConnected
        case illegalState(message: String)
    }

    enum Status: Int, CustomDebugStringConvertible {
        case unknown
        case `init`
        case opened
        case listening
        case connecting
        case connected
        case broken
        case closing
        case closed
        case nonexist

        var debugDescription: String {
            switch self {
            case .unknown:
                return "unknown"
            case .`init`:
                return "init"
            case .opened:
                return "opened"
            case .listening:
                return "listening"
            case .connecting:
                return "connecting"
            case .connected:
                return "connected"
            case .broken:
                return "broken"
            case .closing:
                return "closing"
            case .closed:
                return "closed"
            case .nonexist:
                return "nonexist"
            }
        }

        init?(_ status: SRT_SOCKSTATUS) {
            self.init(rawValue: Int(status.rawValue))
            defer {
                logger.trace(debugDescription)
            }
        }
    }

    var inputs: AsyncStream<Data> {
        AsyncStream<Data> { continuation in
            // If Task.detached is not used, closing will result in a deadlock.
            Task.detached {
                while await self.connected {
                    let result = await self.recvmsg()
                    if 0 <= result {
                        continuation.yield(await self.incomingBuffer.subdata(in: 0..<Data.Index(result)))
                    } else {
                        continuation.finish()
                    }
                }
            }
        }
    }

    var performanceData: SRTPerformanceData {
        .init(mon: perf)
    }

    var status: Status {
        .init(srt_getsockstate(socket)) ?? .unknown
    }

    private(set) var isRunning = false
    private var perf: CBytePerfMon = .init()
    private var socket: SRTSOCKET = SRT_INVALID_SOCK
    private var options: [SRTSocketOption: any Sendable] = [:]
    private var outputs: AsyncStream<Data>.Continuation? {
        didSet {
            oldValue?.finish()
        }
    }
    private var connected: Bool {
        status == .connected
    }
    private var windowSizeC: Int32 = 1024 * 4
    private lazy var incomingBuffer: Data = .init(count: Int(windowSizeC))

    init() {
    }

    init(socket: SRTSOCKET) async throws {
        self.socket = socket
        guard configure(.post) else {
            throw makeSocketError()
        }
        if incomingBuffer.count < windowSizeC {
            incomingBuffer = .init(count: Int(windowSizeC))
        }
    }

    func open(_ addr: sockaddr_in, mode: SRTMode, options: [SRTSocketOption: any Sendable] = [:]) async throws {
        guard socket == SRT_INVALID_SOCK else {
            return
        }
        // prepare socket
        socket = srt_create_socket()
        if socket == SRT_INVALID_SOCK {
            throw makeSocketError()
        }
        self.options = options
        guard configure(.pre) else {
            throw makeSocketError()
        }
        // prepare connect
        var addr_cp = addr
        var stat = withUnsafePointer(to: &addr_cp) { ptr -> Int32 in
            let psa = UnsafeRawPointer(ptr).assumingMemoryBound(to: sockaddr.self)
            return mode.open(socket, psa, Int32(MemoryLayout.size(ofValue: addr)))
        }
        if stat == SRT_ERROR {
            throw makeSocketError()
        }
        switch mode {
        case .caller:
            guard configure(.post) else {
                throw makeSocketError()
            }
            if incomingBuffer.count < windowSizeC {
                incomingBuffer = .init(count: Int(windowSizeC))
            }
        case .listener:
            // only supporting a single connection
            stat = srt_listen(socket, 1)
            if stat == SRT_ERROR {
                srt_close(socket)
                throw makeSocketError()
            }
        }
        await startRunning()
    }

    func accept() async throws -> SRTSocket {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<SRTSocket, Swift.Error>) in
            Task.detached { [self] in
                do {
                    let accept = srt_accept(await socket, nil, nil)
                    guard -1 < accept else {
                        throw await makeSocketError()
                    }
                    let socket = try await SRTSocket(socket: accept)
                    await socket.startRunning()
                    continuation.resume(returning: socket)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func send(_ data: Data) throws {
        guard connected else {
            throw Error.notConnected
        }
        for data in data.chunk(Self.payloadSize) {
            outputs?.yield(data)
        }
    }

    private func configure(_ binding: SRTSocketOption.Binding) -> Bool {
        let failures = SRTSocketOption.configure(socket, binding: binding, options: options)
        guard failures.isEmpty else {
            logger.error(failures)
            return false
        }
        return true
    }

    private func bstats() -> Int32 {
        guard socket != SRT_INVALID_SOCK else {
            return SRT_ERROR
        }
        return srt_bstats(socket, &perf, 1)
    }

    private func makeSocketError() -> SRTError {
        let error_message = String(cString: srt_getlasterror_str())
        defer {
            logger.error(error_message)
        }
        return .illegalState(message: error_message)
    }

    @inline(__always)
    private func sendmsg(_ data: Data) -> Int32 {
        return data.withUnsafeBytes { pointer in
            guard let buffer = pointer.baseAddress?.assumingMemoryBound(to: CChar.self) else {
                return SRT_ERROR
            }
            return srt_sendmsg(socket, buffer, Int32(data.count), -1, 0)
        }
    }

    @inline(__always)
    private func recvmsg() -> Int32 {
        return incomingBuffer.withUnsafeMutableBytes { pointer in
            guard let buffer = pointer.baseAddress?.assumingMemoryBound(to: CChar.self) else {
                return SRT_ERROR
            }
            return srt_recvmsg(socket, buffer, windowSizeC)
        }
    }
    
    deinit {
        print("⚔️ deinit -> \(String(describing: self))")
    }
}

extension SRTSocket: AsyncRunner {
    // MARK: AsyncRunner
    func startRunning() async {
        guard !isRunning else {
            return
        }
        let stream = AsyncStream<Data> { continuation in
            self.outputs = continuation
        }
        Task {
            for await data in stream {
                let result = sendmsg(data)
                if result == -1 {
                    await stopRunning()
                }
            }
        }
        isRunning = true
    }

    func stopRunning() async {
        guard isRunning else {
            return
        }
        srt_close(socket)
        socket = SRT_INVALID_SOCK
        outputs = nil
        isRunning = false
    }
}

extension SRTSocket: NetworkTransportReporter {
    // MARK: NetworkTransportReporter
    func makeNetworkTransportReport() -> NetworkTransportReport {
        _ = bstats()
        let performanceData = self.performanceData
        return .init(
            queueBytesOut: Int(performanceData.byteSndBuf),
            totalBytesIn: Int(performanceData.byteRecvTotal),
            totalBytesOut: Int(performanceData.byteSentTotal)
        )
    }

    func makeNetworkMonitor() -> NetworkMonitor {
        return .init(self)
    }
}
