import Foundation
import HaishinKit
import libsrt
import Logboard

final actor SRTSocket {
    static let payloadSize: Int = 1316

    var inputs: AsyncStream<Data> {
        AsyncStream<Data> { condination in
            // If Task.detached is not used, closing will result in a deadlock.
            Task.detached {
                while await self.connected {
                    let result = await self.recvmsg()
                    if 0 < result {
                        condination.yield(await self.incomingBuffer.subdata(in: 0..<Data.Index(result)))
                    } else {
                        condination.finish()
                    }
                }
            }
        }
    }

    var accept: AsyncStream<SRTSocket> {
        AsyncStream<SRTSocket> { condination in
            Task.detached {
                repeat {
                    do {
                        let client = try await self.accept()
                        condination.yield(client)
                        try await Task.sleep(nanoseconds: 1_000_000_000)
                    } catch {
                        condination.finish()
                    }
                } while await self.connected
            }
        }
    }

    private(set) var mode: SRTMode = .caller
    private(set) var perf: CBytePerfMon = .init()
    private(set) var socket: SRTSOCKET = SRT_INVALID_SOCK
    private(set) var status: SRT_SOCKSTATUS = SRTS_INIT {
        didSet {
            guard status != oldValue else {
                return
            }
            switch status {
            case SRTS_INIT: // 1
                logger.trace("SRT Socket Init")
            case SRTS_OPENED:
                logger.info("SRT Socket opened")
            case SRTS_LISTENING:
                logger.trace("SRT Socket Listening")
            case SRTS_CONNECTING:
                logger.trace("SRT Socket Connecting")
            case SRTS_CONNECTED:
                logger.info("SRT Socket Connected")
                didConnected()
            case SRTS_BROKEN:
                logger.warn("SRT Socket Broken")
                close()
            case SRTS_CLOSING:
                logger.trace("SRT Socket Closing")
            case SRTS_CLOSED:
                logger.info("SRT Socket Closed")
            case SRTS_NONEXIST:
                logger.warn("SRT Socket Not Exist")
            default:
                break
            }
        }
    }
    private(set) var options: [SRTSocketOption: Any] = [:]
    private(set) var connected = false
    private var totalBytesIn: Int = 0
    private var totalBytesOut: Int = 0
    private var queueBytesOut: Int = 0
    private var windowSizeC: Int32 = 1024 * 4
    private var outputs: AsyncStream<Data>.Continuation?
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
        status = srt_getsockstate(socket)
        switch status {
        case SRTS_CONNECTED:
            didConnected()
        default:
            break
        }
    }

    func open(_ addr: sockaddr_in, mode: SRTMode, options: [SRTSocketOption: any Sendable] = [:]) throws {
        guard socket == SRT_INVALID_SOCK else {
            return
        }
        self.mode = mode
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
        status = srt_getsockstate(socket)
    }

    func close() {
        guard socket != SRT_INVALID_SOCK else {
            return
        }
        srt_close(socket)
        socket = SRT_INVALID_SOCK
    }

    func send(_ data: Data) {
        for data in data.chunk(Self.payloadSize) {
            queueBytesOut += data.count
            outputs?.yield(data)
        }
    }

    func configure(_ binding: SRTSocketOption.Binding) -> Bool {
        let failures = SRTSocketOption.configure(socket, binding: binding, options: options)
        guard failures.isEmpty else {
            logger.error(failures)
            return false
        }
        return true
    }

    func bstats() -> Int32 {
        guard socket != SRT_INVALID_SOCK else {
            return SRT_ERROR
        }
        return srt_bstats(socket, &perf, 1)
    }

    private func didConnected() {
        connected = true
        let (stream, continuation) = AsyncStream<Data>.makeStream()
        outputs = continuation
        Task {
            for await data in stream where connected {
                _ = sendmsg2(data)
                totalBytesOut += data.count
                queueBytesOut -= data.count
            }
        }
    }

    private func makeSocketError() -> SRTError {
        let error_message = String(cString: srt_getlasterror_str())
        logger.error(error_message)
        return SRTError.illegalState(message: error_message)
    }

    private func accept() async throws -> SRTSocket {
        let accept = srt_accept(socket, nil, nil)
        return try await SRTSocket(socket: accept)
    }

    @inline(__always)
    private func sendmsg2(_ data: Data) -> Int32 {
        return data.withUnsafeBytes { pointer in
            guard let buffer = pointer.baseAddress?.assumingMemoryBound(to: CChar.self) else {
                return SRT_ERROR
            }
            return srt_sendmsg2(socket, buffer, Int32(data.count), nil)
        }
    }

    @inline(__always)
    private func recvmsg() -> Int32 {
        let result = incomingBuffer.withUnsafeMutableBytes { pointer in
            guard let buffer = pointer.baseAddress?.assumingMemoryBound(to: CChar.self) else {
                return SRT_ERROR
            }
            return srt_recvmsg(socket, buffer, windowSizeC)
        }
        totalBytesIn += Int(result)
        return result
    }
}

extension SRTSocket: NetworkTransportReporter {
    // MARK: NetworkTransportReporter
    func makeNetworkTransportReport() -> NetworkTransportReport {
        return .init(
            queueBytesOut: queueBytesOut,
            totalBytesIn: totalBytesIn,
            totalBytesOut: totalBytesOut
        )
    }

    func makeNetworkMonitor() -> NetworkMonitor {
        return .init(self)
    }
}
