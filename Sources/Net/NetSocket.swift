import Foundation

class NetSocket: NSObject {
    static let defaultTimeout:Int64 = 15 // sec
    static let defaultWindowSizeC:Int = 1024 * 1

    var timeout:Int64 = NetSocket.defaultTimeout
    var connected:Bool = false
    var inputBuffer:[UInt8] = []
    var inputStream:NSInputStream?
    var windowSizeC:Int = NetSocket.defaultWindowSizeC
    var outputStream:NSOutputStream?
    var networkQueue:dispatch_queue_t = dispatch_queue_create(
        "com.github.shogo4405.lf.NetSocket.network", DISPATCH_QUEUE_SERIAL
    )
    var securityLevel:String = NSStreamSocketSecurityLevelNone
    private(set) var totalBytesIn:Int64 = 0
    private(set) var totalBytesOut:Int64 = 0

    private var runloop:NSRunLoop?
    private let lockQueue:dispatch_queue_t = dispatch_queue_create(
        "com.github.shogo4405.lf.NetSocket.lock", DISPATCH_QUEUE_SERIAL
    )
    private var timeoutHandler:(() -> Void)?

    final func doOutput(data data:NSData) -> Int {
        dispatch_async(lockQueue) {
            self.doOutputProcess(UnsafePointer<UInt8>(data.bytes), maxLength: data.length)
        }
        return data.length
    }

    final func doOutput(bytes bytes:[UInt8]) -> Int {
        dispatch_async(lockQueue) {
            self.doOutputProcess(UnsafePointer<UInt8>(bytes), maxLength: bytes.count)
        }
        return bytes.count
    }

    final func doOutputFromURL(url:NSURL, length:Int) {
        dispatch_async(lockQueue) {
            do {
                let fileHandle:NSFileHandle = try NSFileHandle(forReadingFromURL: url)
                defer {
                    fileHandle.closeFile()
                }
                let endOfFile:Int = Int(fileHandle.seekToEndOfFile())
                for i in 0..<Int(endOfFile / length) {
                    fileHandle.seekToFileOffset(UInt64(i * length))
                    self.doOutputProcess(fileHandle.readDataOfLength(length))
                }
                let remain:Int = endOfFile % length
                if (0 < remain) {
                    self.doOutputProcess(fileHandle.readDataOfLength(remain))
                }
            } catch let error as NSError {
                logger.error("\(error)")
            }
        }
    }

    final func doOutputProcess(data:NSData) {
        doOutputProcess(UnsafePointer<UInt8>(data.bytes), maxLength: data.length)
    }

    final func doOutputProcess(buffer:UnsafePointer<UInt8>, maxLength:Int) {
        guard let outputStream:NSOutputStream = outputStream else {
            return
        }
        var total:Int = 0
        while total < maxLength {
            let length:Int = outputStream.write(buffer.advancedBy(total), maxLength: maxLength - total)
            if (length <= 0) {
                break
            }
            total += length
            totalBytesOut += Int64(length)
        }
    }

    func close(disconnect:Bool) {
        dispatch_async(lockQueue) {
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
        connected = false
        totalBytesIn = 0
        totalBytesOut = 0
        timeoutHandler = didTimeout
        inputBuffer.removeAll(keepCapacity: false)

        guard let inputStream:NSInputStream = inputStream, outputStream:NSOutputStream = outputStream else {
            return
        }
        
        runloop = NSRunLoop.currentRunLoop()

        inputStream.delegate = self
        inputStream.scheduleInRunLoop(runloop!, forMode: NSDefaultRunLoopMode)
        inputStream.setProperty(securityLevel, forKey: NSStreamSocketSecurityLevelKey)

        outputStream.delegate = self
        outputStream.scheduleInRunLoop(runloop!, forMode: NSDefaultRunLoopMode)
        outputStream.setProperty(securityLevel, forKey: NSStreamSocketSecurityLevelKey)

        inputStream.open()
        outputStream.open()
        runloop?.run()

        if (0 < timeout) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, timeout * Int64(NSEC_PER_SEC)), lockQueue) {
                guard let timeoutHandler:(() -> Void) = self.timeoutHandler else {
                    return
                }
                timeoutHandler()
            }
        }
    }

    func deinitConnection(disconnect:Bool) {
        inputStream?.close()
        inputStream?.removeFromRunLoop(runloop!, forMode: NSDefaultRunLoopMode)
        inputStream?.delegate = nil
        inputStream = nil
        outputStream?.close()
        outputStream?.removeFromRunLoop(runloop!, forMode: NSDefaultRunLoopMode)
        outputStream?.delegate = nil
        outputStream = nil
    }

    func didTimeout() {
    }

    private func doInput() {
        guard let inputStream = inputStream else {
            return
        }
        var buffer:[UInt8] = [UInt8](count: windowSizeC, repeatedValue: 0)
        let length:Int = inputStream.read(&buffer, maxLength: windowSizeC)
        if 0 < length {
            totalBytesIn += Int64(length)
            inputBuffer.appendContentsOf(buffer[0..<length])
            listen()
        }
    }
}

// MARK: NSStreamDelegate
extension NetSocket: NSStreamDelegate {
    func stream(aStream: NSStream, handleEvent eventCode: NSStreamEvent) {
        if (logger.isEnabledForLogLevel(.Debug)) {
            logger.debug("eventCode: \(eventCode)")
        }
        switch eventCode {
        //  0
        case NSStreamEvent.None:
            break
        //  1 = 1 << 0
        case NSStreamEvent.OpenCompleted:
            guard let inputStream = inputStream, outputStream = outputStream
                where
                    inputStream.streamStatus == .Open &&
                    outputStream.streamStatus == .Open else {
                break
            }
            if (aStream == inputStream) {
                timeoutHandler = nil
                connected = true
            }
        //  2 = 1 << 1
        case NSStreamEvent.HasBytesAvailable:
            if (aStream == inputStream) {
                doInput()
            }
        //  4 = 1 << 2
        case NSStreamEvent.HasSpaceAvailable:
            break
        //  8 = 1 << 3
        case NSStreamEvent.ErrorOccurred:
            close(true)
        // 16 = 1 << 4
        case NSStreamEvent.EndEncountered:
            close(true)
        default:
            break
        }
    }
}
