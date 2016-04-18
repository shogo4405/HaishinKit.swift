import Foundation

// MARK: NetSocket
class NetSocket: NSObject {
    static let defaultWindowSizeC:Int = 8 * 1024

    var inputBuffer:[UInt8] = []
    var inputStream:NSInputStream?
    var windowSizeC:Int = NetSocket.defaultWindowSizeC
    var outputStream:NSOutputStream?

    private(set) var totalBytesIn = 0
    private(set) var totalBytesOut = 0
    private var runloop:NSRunLoop?
    private let lockQueue:dispatch_queue_t = dispatch_queue_create(
        "com.github.shogo4405.lf.NetSocket.lock", DISPATCH_QUEUE_SERIAL
    )

    final func doOutput(data:NSData) {
        dispatch_async(lockQueue) {
            self.doOutputProcess(UnsafePointer<UInt8>(data.bytes), maxLength: data.length)
        }
    }

    final func doOutput(bytes:[UInt8]) {
        dispatch_async(lockQueue) {
            self.doOutputProcess(UnsafePointer<UInt8>(bytes), maxLength: bytes.count)
        }
    }

    final func doOutputFromURL(url:NSURL, length:Int) {
        dispatch_async(lockQueue) {
            do {
                let fileHandle:NSFileHandle = try NSFileHandle(forReadingFromURL: url)
                let endOfFile:Int = Int(fileHandle.seekToEndOfFile())
                for i in 0..<Int(endOfFile / length) {
                    fileHandle.seekToFileOffset(UInt64(i * length))
                    self.doOutput(fileHandle.readDataOfLength(length))
                }
                let remain:Int = endOfFile % length
                if (0 < remain) {
                    self.doOutput(fileHandle.readDataOfLength(remain))
                }
                defer {
                    fileHandle.closeFile()
                }
            } catch let error as NSError {
                logger.error("\(error)")
            }
        }
    }

    final func doOutputProcess(buffer:UnsafePointer<UInt8>, maxLength:Int) {
        var total:Int = 0
        while total < maxLength {
            guard let length:Int = self.outputStream?.write(buffer + total, maxLength: maxLength - total) else {
                self.close(true)
                return
            }
            total += length
            totalBytesOut += length
        }
    }

    func close(disconnect:Bool) {
        dispatch_async(lockQueue) {
            guard let runloop = self.runloop else {
                return
            }
            CFRunLoopStop(runloop.getCFRunLoop())
            self.inputStream?.close()
            self.inputStream?.removeFromRunLoop(runloop, forMode: NSDefaultRunLoopMode)
            self.inputStream?.delegate = nil
            self.inputStream = nil
            self.outputStream?.close()
            self.outputStream?.removeFromRunLoop(runloop, forMode: NSDefaultRunLoopMode)
            self.outputStream?.delegate = nil
            self.outputStream = nil
            self.runloop = nil
        }
    }

    func listen() {
    }

    func didOpenCompleted() {
    }

    final func initConnection() {
        guard let inputStream:NSInputStream = inputStream, outputStream:NSOutputStream = outputStream else {
            return
        }
        runloop = NSRunLoop.currentRunLoop()
        totalBytesIn = 0
        totalBytesOut = 0
        inputBuffer.removeAll(keepCapacity: false)
        inputStream.delegate = self
        inputStream.scheduleInRunLoop(runloop!, forMode: NSDefaultRunLoopMode)
        outputStream.delegate = self
        outputStream.scheduleInRunLoop(runloop!, forMode: NSDefaultRunLoopMode)
        inputStream.open()
        outputStream.open()
        runloop!.run()
    }

    private func doInput() {
        guard let inputStream = inputStream else {
            return
        }
        var buffer:[UInt8] = [UInt8](count: windowSizeC, repeatedValue: 0)
        let length:Int = inputStream.read(&buffer, maxLength: windowSizeC)
        if 0 < length {
            inputBuffer += Array(buffer[0..<length])
            listen()
        }
    }
}

// MARK: - NSStreamDelegate
extension NetSocket: NSStreamDelegate {
    func stream(aStream: NSStream, handleEvent eventCode: NSStreamEvent) {
        switch eventCode {
        case NSStreamEvent.None:
            break
        case NSStreamEvent.OpenCompleted:
            guard let inputStream = inputStream, outputStream = outputStream
                where
                    inputStream.streamStatus == NSStreamStatus.Open &&
                    outputStream.streamStatus == NSStreamStatus.Open else {
                break
            }
            didOpenCompleted()
        case NSStreamEvent.HasSpaceAvailable:
            break
        case NSStreamEvent.HasBytesAvailable:
            if (aStream == inputStream) {
                doInput()
            }
        case NSStreamEvent.ErrorOccurred:
            close(true)
        case NSStreamEvent.EndEncountered:
            break
        default:
            break
        }
    }
}
