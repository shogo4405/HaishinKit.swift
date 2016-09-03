import Foundation

class NetSocket: NSObject {
    static let defaultTimeout:Int64 = 15 // sec
    static let defaultWindowSizeC:Int = 1024 * 1

    var timeout:Int64 = NetSocket.defaultTimeout
    var connected:Bool = false
    var inputBuffer:[UInt8] = []
    var inputStream:InputStream?
    var windowSizeC:Int = NetSocket.defaultWindowSizeC
    var outputStream:OutputStream?
    var networkQueue:DispatchQueue = DispatchQueue(
        label: "com.github.shogo4405.lf.NetSocket.network", attributes: []
    )
    var securityLevel:StreamSocketSecurityLevel = .none
    fileprivate(set) var totalBytesIn:Int64 = 0
    fileprivate(set) var totalBytesOut:Int64 = 0

    fileprivate var runloop:RunLoop?
    fileprivate let lockQueue:DispatchQueue = DispatchQueue(
        label: "com.github.shogo4405.lf.NetSocket.lock", attributes: []
    )
    fileprivate var timeoutHandler:(() -> Void)?

    @discardableResult
    final func doOutput(data:Data) -> Int {
        lockQueue.async {
            self.doOutputProcess((data as NSData).bytes.bindMemory(to: UInt8.self, capacity: data.count), maxLength: data.count)
        }
        return data.count
    }

    @discardableResult
    final func doOutput(bytes:[UInt8]) -> Int {
        lockQueue.async {
            self.doOutputProcess(UnsafePointer<UInt8>(bytes), maxLength: bytes.count)
        }
        return bytes.count
    }

    final func doOutputFromURL(_ url:URL, length:Int) {
        lockQueue.async {
            do {
                let fileHandle:FileHandle = try FileHandle(forReadingFrom: url)
                defer {
                    fileHandle.closeFile()
                }
                let endOfFile:Int = Int(fileHandle.seekToEndOfFile())
                for i in 0..<Int(endOfFile / length) {
                    fileHandle.seek(toFileOffset: UInt64(i * length))
                    self.doOutputProcess(fileHandle.readData(ofLength: length))
                }
                let remain:Int = endOfFile % length
                if (0 < remain) {
                    self.doOutputProcess(fileHandle.readData(ofLength: remain))
                }
            } catch let error as NSError {
                logger.error("\(error)")
            }
        }
    }

    final func doOutputProcess(_ data:Data) {
        doOutputProcess((data as NSData).bytes.bindMemory(to: UInt8.self, capacity: data.count), maxLength: data.count)
    }

    final func doOutputProcess(_ buffer:UnsafePointer<UInt8>, maxLength:Int) {
        guard let outputStream:OutputStream = outputStream else {
            return
        }
        var total:Int = 0
        while total < maxLength {
            let length:Int = outputStream.write(buffer.advanced(by: total), maxLength: maxLength - total)
            if (length <= 0) {
                break
            }
            total += length
            totalBytesOut += Int64(length)
        }
    }

    func close(_ disconnect:Bool) {
        lockQueue.async {
            guard let runloop = self.runloop else {
                return
            }
            self.deinitConnection(disconnect)
            self.runloop = nil
            CFRunLoopStop(runloop.getCFRunLoop())
            logger.verbose("disconnect:\(disconnect)")
        }
    }

    func listen() {
    }

    func initConnection() {
        /*
        totalBytesIn = 0
        totalBytesOut = 0
        timeoutHandler = didTimeout
        inputBuffer.removeAll(keepingCapacity: false)

        guard let inputStream:InputStream = inputStream, let outputStream:OutputStream = outputStream else {
            return
        }

        runloop = RunLoop.current

        inputStream.delegate = self
        inputStream.schedule(in: runloop!, forMode: RunLoopMode.defaultRunLoopMode)
        inputStream.setProperty(securityLevel, forKey: Foundation.Stream.PropertyKey.socketSecurityLevelKey)

        outputStream.delegate = self
        outputStream.schedule(in: runloop!, forMode: RunLoopMode.defaultRunLoopMode)
        outputStream.setProperty(securityLevel, forKey: Foundation.Stream.PropertyKey.socketSecurityLevelKey)

        inputStream.open()
        outputStream.open()

        if (0 < timeout) {
            lockQueue.asyncAfter(deadline: DispatchTime.now() + Double(timeout * Int64(NSEC_PER_SEC)) / Double(NSEC_PER_SEC)) {
                guard let timeoutHandler:(() -> Void) = self.timeoutHandler else {
                    return
                }
                timeoutHandler()
            }
        }

        runloop?.run()
        connected = false
        */
    }

    func deinitConnection(_ disconnect:Bool) {
        inputStream?.close()
        inputStream?.remove(from: runloop!, forMode: RunLoopMode.defaultRunLoopMode)
        inputStream?.delegate = nil
        inputStream = nil
        outputStream?.close()
        outputStream?.remove(from: runloop!, forMode: RunLoopMode.defaultRunLoopMode)
        outputStream?.delegate = nil
        outputStream = nil
    }

    func didTimeout() {
    }

    fileprivate func doInput() {
        guard let inputStream = inputStream else {
            return
        }
        var buffer:[UInt8] = [UInt8](repeating: 0, count: windowSizeC)
        let length:Int = inputStream.read(&buffer, maxLength: windowSizeC)
        if 0 < length {
            totalBytesIn += Int64(length)
            inputBuffer.append(contentsOf: buffer[0..<length])
            listen()
        }
    }
}

// MARK: NSStreamDelegate
extension NetSocket: StreamDelegate {
    func stream(_ aStream: Foundation.Stream, handle eventCode: Foundation.Stream.Event) {
        if (logger.isEnabledForLogLevel(.debug)) {
            logger.debug("eventCode: \(eventCode)")
        }
        switch eventCode {
        //  1 = 1 << 0
        case Foundation.Stream.Event.openCompleted:
            guard let inputStream = inputStream, let outputStream = outputStream,
                inputStream.streamStatus == .open && outputStream.streamStatus == .open else {
                break
            }
            if (aStream == inputStream) {
                timeoutHandler = nil
                connected = true
            }
        //  2 = 1 << 1
        case Foundation.Stream.Event.hasBytesAvailable:
            if (aStream == inputStream) {
                doInput()
            }
        //  4 = 1 << 2
        case Foundation.Stream.Event.hasSpaceAvailable:
            break
        //  8 = 1 << 3
        case Foundation.Stream.Event.errorOccurred:
            close(true)
        // 16 = 1 << 4
        case Foundation.Stream.Event.endEncountered:
            close(true)
        default:
            break
        }
    }
}
