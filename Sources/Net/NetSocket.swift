import Foundation

/// The NetSocket class creates a two-way connection between a client and a server as a client. This class is wrapper for a InputStream and an OutputStream.
open class NetSocket: NSObject {
    /// The default time to wait for TCP/IP Handshake done.
    public static let defaultTimeout: Int = 15 // sec
    /// The defulat stream's TCP window size.
    public static let defaultWindowSizeC = Int(UInt16.max)
    /// The current incoming data buffer.
    public var inputBuffer = Data()
    /// Specifies time to wait for TCP/IP Handshake done.
    public var timeout: Int = NetSocket.defaultTimeout
    /// Specifies  instance connected to server(true) or not(false).
    public var connected = false
    /// Specifies the output buffer size in bytes.
    public var windowSizeC: Int = NetSocket.defaultWindowSizeC
    /// Specifies  statistics of total incoming bytes.
    public var totalBytesIn: Atomic<Int64> = .init(0)
    /// Specifies  instance's quality of service for a Socket IO.
    public var qualityOfService: DispatchQoS = .userInitiated
    /// Specifies instance determine to use the secure-socket layer (SSL) security level.
    public var securityLevel: StreamSocketSecurityLevel = .none
    /// Specifies the output buffer size in bytes.
    public var outputBufferSize: Int = NetSocket.defaultWindowSizeC
    /// Specifies  statistics of total outgoing bytes.
    public private(set) var totalBytesOut: Atomic<Int64> = .init(0)
    /// Specifies  statistics of total outgoing queued bytes.
    public private(set) var queueBytesOut: Atomic<Int64> = .init(0)

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
    private var timeoutHandler: DispatchWorkItem?
    private lazy var buffer = [UInt8](repeating: 0, count: windowSizeC)
    private lazy var outputBuffer: DataBuffer = .init(capacity: outputBufferSize)
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

    /// Does output data buffer to the server.
    @discardableResult
    public func doOutput(data: Data, locked: UnsafeMutablePointer<UInt32>? = nil) -> Int {
        queueBytesOut.mutate { $0 += Int64(data.count) }
        outputQueue.async { [weak self] in
            guard let self = self else {
                return
            }
            self.outputBuffer.append(data)
            if let outputStream = self.outputStream, outputStream.hasSpaceAvailable {
                self.doOutput(outputStream)
            }
        }
        return data.count
    }

    /// Closes the connection from the server.
    open func close() {
        close(isDisconnected: false)
    }

    /// Listen incoming data buffer from the server.
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
        totalBytesIn.mutate { $0 = 0 }
        totalBytesOut.mutate { $0 = 0 }
        queueBytesOut.mutate { $0 = 0 }
        inputBuffer.removeAll(keepingCapacity: false)
        if outputBuffer.capacity < outputBufferSize {
            outputBuffer = .init(capacity: outputBufferSize)
        } else {
            outputBuffer.clear()
        }
        inputStream.open()
        outputStream.open()
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

    func deinitConnection(isDisconnected: Bool) {
        guard inputStream != nil && outputStream != nil else {
            return
        }
        timeoutHandler?.cancel()
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
        let length = outputStream.write(bytes, maxLength: min(windowSizeC, outputBuffer.maxLength))
        if 0 < length {
            totalBytesOut.mutate { $0 += Int64(length) }
            queueBytesOut.mutate { $0 -= Int64(length) }
            outputBuffer.skip(length)
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
                timeoutHandler?.cancel()
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
