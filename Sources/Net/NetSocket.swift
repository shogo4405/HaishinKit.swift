import Foundation

open class NetSocket: NSObject {
    public static let defaultTimeout: Int = 15 // sec
    public static let defaultWindowSizeC = Int(UInt16.max)

    open var inputBuffer = Data()
    /// The time to wait for TCP/IP Handshake done.
    open var timeout: Int = NetSocket.defaultTimeout
    /// This instance connected to server(true) or not(false).
    open var connected: Bool = false
    public var windowSizeC: Int = NetSocket.defaultWindowSizeC
    /// The statistics of total incoming bytes.
    open var totalBytesIn: Atomic<Int64> = .init(0)
    open var qualityOfService: DispatchQoS = .default
    open var securityLevel: StreamSocketSecurityLevel = .none
    /// The statistics of total outgoing bytes.
    open private(set) var totalBytesOut: Atomic<Int64> = .init(0)
    open private(set) var queueBytesOut: Atomic<Int64> = .init(0)

    var inputStream: InputStream?
    var outputStream: OutputStream?
    lazy var inputQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.NetSocket.input", qos: qualityOfService)

    private var runloop: RunLoop?
    private lazy var timeoutHandler = DispatchWorkItem { [weak self] in
        self?.didTimeout()
    }
    private lazy var buffer = [UInt8](repeating: 0, count: windowSizeC)
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
        outputQueue.async {
            data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> Void in
                self.doOutputProcess(buffer.baseAddress?.assumingMemoryBound(to: UInt8.self), maxLength: data.count)
            }
            if locked != nil {
                OSAtomicAnd32Barrier(0, locked!)
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
        outputQueue.async {
            do {
                let fileHandle: FileHandle = try FileHandle(forReadingFrom: url)
                defer {
                    fileHandle.closeFile()
                }
                let endOfFile = Int(fileHandle.seekToEndOfFile())
                for i in 0..<Int(endOfFile / length) {
                    fileHandle.seek(toFileOffset: UInt64(i * length))
                    self.doOutputProcess(fileHandle.readData(ofLength: length))
                }
                let remain: Int = endOfFile % length
                if 0 < remain {
                    self.doOutputProcess(fileHandle.readData(ofLength: remain))
                }
            } catch let error as NSError {
                logger.error("\(error)")
            }
        }
    }

    final func doOutputProcess(_ data: Data) {
        data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> Void in
            doOutputProcess(buffer.baseAddress?.assumingMemoryBound(to: UInt8.self), maxLength: data.count)
        }
    }

    final func doOutputProcess(_ buffer: UnsafePointer<UInt8>?, maxLength: Int) {
        guard let buffer = buffer, 0 < maxLength else {
            return
        }
        var total: Int = 0
        repeat {
            guard let outputStream = outputStream else {
                return
            }
            let length = outputStream.write(buffer.advanced(by: total), maxLength: maxLength - total)
            if 0 < length {
                total += length
                totalBytesOut.mutate { $0 += Int64(length) }
                queueBytesOut.mutate { $0 -= Int64(length) }
            }
        } while total < maxLength
    }

    func close(isDisconnected: Bool) {
        outputQueue.async {
            guard self.runloop != nil else {
                return
            }
            self.deinitConnection(isDisconnected: isDisconnected)
        }
    }

    func initConnection() {
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
        outputQueue = .init(label: "com.haishinkit.HaishinKit.NetSocket.output", qos: qualityOfService)
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

    private func doInput() {
        guard let inputStream = inputStream, inputStream.streamStatus == .open else {
            return
        }
        let length = inputStream.read(&buffer, maxLength: windowSizeC)
        if 0 < length {
            totalBytesIn.mutate { $0 += Int64(length) }
            inputBuffer.append(buffer, count: length)
            listen()
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
            if aStream == inputStream {
                doInput()
            }
        //  4 = 1 << 2
        case .hasSpaceAvailable:
            break
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
