import Foundation

/// The NetSocket class creates a two-way connection  between a client and a server. This class is wrapper for a InputStream and an OutputStream.
open class NetSocket: NSObject {
    struct CycleBuffer: CustomDebugStringConvertible {
        var bytes: UnsafePointer<UInt8>? {
            data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> UnsafePointer<UInt8>? in
                bytes.baseAddress?.assumingMemoryBound(to: UInt8.self).advanced(by: top)
            }
        }
        var maxLength: Int {
            min(count, capacity - top)
        }
        var debugDescription: String {
            Mirror(reflecting: self).debugDescription
        }
        private var count: Int {
            let value = bottom - top
            return value < 0 ? value + capacity : value
        }
        private var data: Data
        private var capacity: Int = 0 {
            didSet {
                logger.info("extends a buffer size from ", oldValue, " to ", capacity)
            }
        }
        private var top: Int = 0
        private var bottom: Int = 0
        private var locked: UnsafeMutablePointer<UInt32>?
        private var lockedBottom: Int = -1

        init(capacity: Int) {
            self.capacity = capacity
            data = .init(repeating: 0, count: capacity)
        }

        mutating func append(_ data: Data, locked: UnsafeMutablePointer<UInt32>? = nil) {
            guard data.count + count < capacity else {
                extend(data)
                return
            }
            let count = data.count
            if self.locked == nil {
                self.locked = locked
            }
            let length = min(count, capacity - bottom)
            self.data.replaceSubrange(bottom..<bottom + length, with: data)
            if length < count {
                bottom = count - length
                self.data.replaceSubrange(0..<bottom, with: data.advanced(by: length))
            } else {
                bottom += count
            }
            if capacity == bottom {
                bottom = 0
            }
            if locked != nil {
                lockedBottom = bottom
            }
        }

        mutating func markAsRead(_ count: Int) {
            let length = min(count, capacity - top)
            if length < count {
                top = count - length
            } else {
                top += count
            }
            if capacity == top {
                top = 0
            }
            if let locked = locked, -1 < lockedBottom && lockedBottom <= top {
                OSAtomicAnd32Barrier(0, locked)
                lockedBottom = -1
            }
        }

        mutating func clear() {
            top = 0
            bottom = 0
            locked = nil
            lockedBottom = 0
        }

        private mutating func extend(_ data: Data) {
            if 0 < top {
                let subdata = self.data.subdata(in: 0..<bottom)
                self.data.replaceSubrange(0..<capacity - top, with: self.data.advanced(by: top))
                self.data.replaceSubrange(capacity - top..<capacity - top + subdata.count, with: subdata)
                bottom = capacity - top + subdata.count
            }
            self.data.append(.init(count: capacity))
            top = 0
            capacity = self.data.count
            append(data)
        }
    }

    /// The default time to wait for TCP/IP Handshake done.
    public static let defaultTimeout: Int = 15 // sec
    public static let defaultWindowSizeC = Int(UInt16.max)

    open var inputBuffer = Data()
    /// The time to wait for TCP/IP Handshake done.
    open var timeout: Int = NetSocket.defaultTimeout
    /// This instance connected to server(true) or not(false).
    open var connected: Bool = false
    open var windowSizeC: Int = NetSocket.defaultWindowSizeC
    /// The statistics of total incoming bytes.
    open var totalBytesIn: Atomic<Int64> = .init(0)
    /// The instance's quality of service for a Socket IO.
    open var qualityOfService: DispatchQoS = .userInitiated
    /// The instance determine to use the secure-socket layer (SSL) security level.
    open var securityLevel: StreamSocketSecurityLevel = .none
    /// The statistics of total outgoing bytes.
    open private(set) var totalBytesOut: Atomic<Int64> = .init(0)
    /// The statistics of total outgoing queued bytes.
    open private(set) var queueBytesOut: Atomic<Int64> = .init(0)

    var inputStream: InputStream? {
        didSet {
            inputStream?.delegate = self
            inputStream?.setProperty(securityLevel.rawValue, forKey: .socketSecurityLevelKey)
            if let inputStream = inputStream {
                CFReadStreamSetDispatchQueue(inputStream, inputQueue)
            }
            if let oldValue = oldValue {
                oldValue.delegate = nil
                CFReadStreamSetDispatchQueue(oldValue, nil)
            }
        }
    }
    var outputStream: OutputStream? {
        didSet {
            outputStream?.delegate = self
            outputStream?.setProperty(securityLevel.rawValue, forKey: .socketSecurityLevelKey)
            if let outputStream = outputStream {
                CFWriteStreamSetDispatchQueue(outputStream, outputQueue)
            }
            if let oldValue = oldValue {
                oldValue.delegate = nil
                CFWriteStreamSetDispatchQueue(oldValue, nil)
            }
        }
    }
    lazy var inputQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.NetSocket.input", qos: qualityOfService)
    private lazy var timeoutHandler = DispatchWorkItem { [weak self] in
        self?.didTimeout()
    }
    private lazy var buffer = [UInt8](repeating: 0, count: windowSizeC)
    private lazy var outputBuffer: CycleBuffer = .init(capacity: windowSizeC)
    private lazy var outputQueue: DispatchQueue = .init(label: "com.haishinkit.HaishinKit.NetSocket.output", qos: qualityOfService)

    deinit {
        inputStream?.delegate = nil
        outputStream?.delegate = nil
    }

    /// Creates a two-way connection to a server.
    public func connect(withName: String, port: Int) {
        inputQueue.async {
            Stream.getStreamsToHost(
                withName: withName,
                port: port,
                inputStream: &self.inputStream,
                outputStream: &self.outputStream
            )
            self.initConnection()
        }
    }

    @discardableResult
    public func doOutput(data: Data, locked: UnsafeMutablePointer<UInt32>? = nil) -> Int {
        queueBytesOut.mutate { $0 += Int64(data.count) }
        outputQueue.async { [weak self] in
            guard let self = self else {
                return
            }
            self.outputBuffer.append(data, locked: locked)
            if let outputStream = self.outputStream, outputStream.hasSpaceAvailable {
                self.doOutput(outputStream)
            }
        }
        return data.count
    }

    open func close() {
        close(isDisconnected: false)
    }

    open func listen() {
    }

    func close(isDisconnected: Bool) {
        outputQueue.async {
            self.deinitConnection(isDisconnected: isDisconnected)
        }
    }

    func initConnection() {
        guard let inputStream = inputStream, let outputStream = outputStream else {
            return
        }
        outputBuffer.clear()
        totalBytesIn.mutate { $0 = 0 }
        totalBytesOut.mutate { $0 = 0 }
        queueBytesOut.mutate { $0 = 0 }
        inputBuffer.removeAll(keepingCapacity: false)
        inputStream.open()
        outputStream.open()
        if 0 < timeout {
            DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + .seconds(timeout), execute: timeoutHandler)
        }
    }

    func deinitConnection(isDisconnected: Bool) {
        guard inputStream != nil && outputStream != nil else {
            return
        }
        timeoutHandler.cancel()
        inputStream?.close()
        inputStream = nil
        outputStream?.close()
        outputStream = nil
        connected = false
        logger.trace("isDisconnected: \(isDisconnected)")
    }

    func didTimeout() {
    }

    private func doInput(_ inputStream: InputStream) {
        let length = inputStream.read(&buffer, maxLength: windowSizeC)
        if 0 < length {
            totalBytesIn.mutate { $0 += Int64(length) }
            inputBuffer.append(buffer, count: length)
            listen()
        }
    }

    private func doOutput(_ outputStream: OutputStream) {
        guard let bytes = outputBuffer.bytes, 0 < outputBuffer.maxLength else {
            return
        }
        let length = outputStream.write(bytes, maxLength: outputBuffer.maxLength)
        if 0 < length {
            totalBytesOut.mutate { $0 += Int64(length) }
            queueBytesOut.mutate { $0 -= Int64(length) }
            outputBuffer.markAsRead(length)
        }
    }
}

extension NetSocket: StreamDelegate {
    // MARK: StreamDelegate
    public func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        //  1 = 1 << 0
        case .openCompleted:
            guard let inputStream = inputStream, let outputStream = outputStream,
                inputStream.streamStatus == .open && outputStream.streamStatus == .open else {
                break
            }
            if aStream == inputStream {
                timeoutHandler.cancel()
                connected = true
            }
        //  2 = 1 << 1
        case .hasBytesAvailable:
            if let aStream = aStream as? InputStream {
                doInput(aStream)
            }
        //  4 = 1 << 2
        case .hasSpaceAvailable:
            if let aStream = aStream as? OutputStream {
                doOutput(aStream)
            }
        //  8 = 1 << 3
        case .errorOccurred:
            guard aStream == inputStream else {
                return
            }
            deinitConnection(isDisconnected: true)
        // 16 = 1 << 4
        case .endEncountered:
            guard aStream == inputStream else {
                return
            }
            deinitConnection(isDisconnected: true)
        default:
            break
        }
    }
}
