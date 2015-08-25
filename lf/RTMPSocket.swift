import Foundation

protocol RTMPSocketDelegate: class {
    func listen(socket: RTMPSocket, bytes:[UInt8])
    func didSetReadyState(socket: RTMPSocket, readyState:RTMPSocket.ReadyState)
}

final class RTMPSocket: NSObject, NSStreamDelegate {

    enum ReadyState:UInt8 {
        case Initialized = 1
        case VersionSent = 2
        case AckSent = 3
        case HandshakeDone = 4
        case Closing = 5
        case Closed = 6
    }
    
    static let sigSize:Int = 1536
    static let defaultChunkSize:Int = 128
    static let defaultBufferSize:Int = 1024

    var readyState:ReadyState = ReadyState.Initialized {
        didSet {
            delegate?.didSetReadyState(self, readyState: readyState)
        }
    }

    var inputBuffer:[UInt8] = []
    var chunkSizeC:Int = RTMPSocket.defaultChunkSize
    var chunkSizeS:Int = RTMPSocket.defaultChunkSize
    var bufferSize:Int = RTMPSocket.defaultBufferSize
    var objectEncoding:UInt8 = RTMPConnection.defaultObjectEncoding
    weak var delegate:RTMPSocketDelegate? = nil

    private var _totalBytesIn:Int = 0
    var totalBytesIn:Int {
        return _totalBytesIn
    }

    private var _totalBytesOut:Int = 0
    var totalBytesOut:Int {
        return _totalBytesOut
    }

    private var running:Bool = false
    private var timestamp:NSTimeInterval = 0
    private var inputStream:NSInputStream? = nil
    private var outputStream:NSOutputStream? = nil
    private var outputQueue:dispatch_queue_t = dispatch_queue_create("com.github.shogo4405.lf.RTMPSocket.network", DISPATCH_QUEUE_SERIAL)

    override init() {
        super.init()
    }

    func doWrite(bytes:[UInt8]) {
        doOutputProcess(bytes)
    }

    func doWrite(chunk:RTMPChunk) {
        println(chunk)
        let chunks:[[UInt8]] = chunk.split(chunkSizeS)
        for chunk in chunks {
            doWrite(chunk)
        }
    }

    func connect(host:CFString, port:UInt32) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
            self.initConnection(host, port: port)
        })
    }

    func close() {
        if (ReadyState.Closing.rawValue <= readyState.rawValue) {
            return
        }
        readyState = .Closing

        inputStream?.delegate = nil
        inputStream?.removeFromRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
        inputStream?.close()

        outputStream?.delegate = nil
        outputStream?.removeFromRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
        outputStream?.close()

        inputStream = nil
        outputStream = nil

        running = false
        readyState = .Closed
    }

    func stream(aStream: NSStream, handleEvent eventCode: NSStreamEvent) {
        switch eventCode {
        case NSStreamEvent.None:
            break
        case NSStreamEvent.OpenCompleted:
            if (inputStream!.streamStatus == NSStreamStatus.Open &&
                outputStream!.streamStatus == NSStreamStatus.Open) {
                handleEvent()
            }
        case NSStreamEvent.HasSpaceAvailable:
            break
        case NSStreamEvent.HasBytesAvailable:
            if (aStream == inputStream) {
                doInputProcess()
            }
        case NSStreamEvent.ErrorOccurred:
            close()
            break
        case NSStreamEvent.EndEncountered:
            break
        default:
            break
        }
    }

    private func initConnection(host:CFString, port:UInt32) {
        readyState = .Initialized

        timestamp = 0
        chunkSizeS = RTMPSocket.defaultChunkSize
        chunkSizeC = RTMPSocket.defaultChunkSize
        bufferSize = RTMPSocket.defaultBufferSize
        _totalBytesIn = 0
        _totalBytesOut = 0
        inputBuffer.removeAll(keepCapacity: false)

        var readStream:Unmanaged<CFReadStream>? = nil
        var writeStream:Unmanaged<CFWriteStream>? = nil
        CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault, host, port, &readStream, &writeStream)
        if (readStream != nil && writeStream != nil) {
            inputStream = readStream!.takeRetainedValue()
            inputStream!.delegate = self
            inputStream!.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
            outputStream = writeStream!.takeRetainedValue()
            outputStream!.delegate = self
            outputStream!.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)

            inputStream!.open()
            outputStream!.open()

            running = true
            while (running) {
                NSRunLoop.currentRunLoop().runMode(NSDefaultRunLoopMode, beforeDate: NSDate.distantFuture() as! NSDate)
            }
        }
    }

    private func doInputProcess() {
        var buffer:[UInt8] = [UInt8](count: bufferSize, repeatedValue: 0)
        let length:Int = inputStream!.read(&buffer, maxLength: bufferSize)
        if 0 < length {
            inputBuffer += Array(buffer[0..<length])
            _totalBytesIn += length
        }
        handleEvent()
    }

    private func doOutputProcess(bytes:[UInt8]) {
        dispatch_async(outputQueue) {
            if (ReadyState.HandshakeDone.rawValue < self.readyState.rawValue) {
                return
            }
            var total:Int = 0
            let buffer:UnsafePointer<UInt8> = UnsafePointer<UInt8>(bytes)
            while total < bytes.count {
                let length:Int? = self.outputStream?.write(buffer + total, maxLength: bytes.count - total)
                if length == nil || length! <= 0 {
                    self.close()
                    break
                }
                total += length!
                self._totalBytesOut += length!
            }
        }
    }

    private func handleEvent() {
        switch readyState {
        case .Initialized:
            timestamp = NSDate().timeIntervalSince1970
            let c1packet:ByteArray = ByteArray()
            c1packet.write(Int32(timestamp))
            c1packet.write([0x00, 0x00, 0x00, 0x00])
            for i in 0..<RTMPSocket.sigSize - 8 {
                c1packet.writeUInt8(UInt8(arc4random_uniform(0xff)))
            }
            doWrite([objectEncoding])
            doWrite(c1packet.bytes)
            readyState = .VersionSent
            break
        case .VersionSent:
            if (inputBuffer.count < RTMPSocket.sigSize + 1) {
                break
            }
            let objectEncoding:UInt8 = inputBuffer[0]
            if (objectEncoding != self.objectEncoding) {
                close()
            }
            let c2packet:ByteArray = ByteArray()
            c2packet.write(Array(inputBuffer[1..<5]))
            c2packet.write(Int32(NSDate().timeIntervalSince1970 - timestamp))
            c2packet.write(Array(inputBuffer[9..<RTMPSocket.sigSize + 1]))
            doWrite(c2packet.bytes)
            inputBuffer = Array(inputBuffer[RTMPSocket.sigSize + 1..<inputBuffer.count])
            readyState = .AckSent
            break
        case .AckSent:
            if (inputBuffer.count < RTMPSocket.sigSize) {
                break
            }
            let s2packet:[UInt8] = Array(inputBuffer[0..<RTMPSocket.sigSize])
            inputBuffer.removeAll(keepCapacity: false)
            readyState = .HandshakeDone
            break
        case .HandshakeDone:
            if (inputBuffer.isEmpty){
                break
            }
            let bytes:[UInt8] = inputBuffer
            inputBuffer.removeAll(keepCapacity: false)
            delegate?.listen(self, bytes: bytes)
            break
        default:
            break
        }
    }
}
