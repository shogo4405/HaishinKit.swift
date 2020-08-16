import Foundation

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
    open var qualityOfService: DispatchQoS = .userInitiated
    open var securityLevel: StreamSocketSecurityLevel = .none
    /// The statistics of total outgoing bytes.
    open private(set) var totalBytesOut: Atomic<Int64> = .init(0)
    /// The statistics of total outgoing queued bytes.
    open private(set) var queueBytesOut: Atomic<Int64> = .init(0)

    var inputStream: InputStream?
    var outputStream: OutputStream?
    lazy var inputQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.NetSocket.input", qos: qualityOfService)

    private var runloop: RunLoop?
    private lazy var timeoutHandler = DispatchWorkItem { [weak self] in
        self?.didTimeout()
    }
    private lazy var buffer = [UInt8](repeating: 0, count: windowSizeC)
    private lazy var outputBuffer: CycleBuffer = .init(capacity: windowSizeC)
    private lazy var outputQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.NetSocket.output", qos: qualityOfService)

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

    final func doOutputFromURL(_ url: URL, length: Int) {
        outputQueue.async { [weak self] in
            guard let self = self else {
                return
            }
            do {
                let fileHandle: FileHandle = try FileHandle(forReadingFrom: url)
                defer {
                    fileHandle.closeFile()
                }
                let endOfFile = Int(fileHandle.seekToEndOfFile())
                for i in 0..<Int(endOfFile / length) {
                    fileHandle.seek(toFileOffset: UInt64(i * length))
                    self.doOutput(data: fileHandle.readData(ofLength: length))
                }
                let remain: Int = endOfFile % length
                if 0 < remain {
                    self.doOutput(data: fileHandle.readData(ofLength: remain))
                }
            } catch let error as NSError {
                logger.error("\(error)")
            }
        }
    }

    func close(isDisconnected: Bool) {
        inputQueue.async {
            guard self.runloop != nil else {
                return
            }
            self.deinitConnection(isDisconnected: isDisconnected)
        }
    }

    func initConnection() {
        outputBuffer.clear()
        totalBytesIn.mutate { $0 = 0 }
        totalBytesOut.mutate { $0 = 0 }
        queueBytesOut.mutate { $0 = 0 }
        inputBuffer.removeAll(keepingCapacity: false)
        guard let inputStream = inputStream, let outputStream = outputStream else {
            return
        }
        runloop = .current
        inputStream.delegate = self
        inputStream.schedule(in: runloop!, forMode: .default)
        inputStream.setProperty(securityLevel.rawValue, forKey: .socketSecurityLevelKey)
        outputStream.delegate = self
        outputStream.schedule(in: runloop!, forMode: .default)
        outputStream.setProperty(securityLevel.rawValue, forKey: .socketSecurityLevelKey)
        CFWriteStreamSetDispatchQueue(outputStream, outputQueue)
        inputStream.open()
        outputStream.open()

        if 0 < timeout {
            DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + .seconds(timeout), execute: timeoutHandler)
        }

        runloop?.run()
        connected = false
    }

    func deinitConnection(isDisconnected: Bool) {
        guard let runloop = runloop else {
            return
        }
        timeoutHandler.cancel()
        inputStream?.close()
        inputStream?.remove(from: runloop, forMode: .default)
        inputStream?.delegate = nil
        inputStream = nil
        outputStream?.close()
        outputStream?.remove(from: runloop, forMode: .default)
        outputStream?.delegate = nil
        outputStream = nil
        self.runloop = nil
        CFRunLoopStop(runloop.getCFRunLoop())
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
