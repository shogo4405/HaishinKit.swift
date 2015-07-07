import Foundation

protocol RTMPSocketDelegate: class {
    func listen(socket: RTMPSocket, bytes:[UInt8])
    func didSetReadyState(socket: RTMPSocket, readyState:RTMPSocketReadyState)
}

enum RTMPSocketReadyState:UInt8 {
    case INITIALIZED = 1
    case VERSION_SENT = 2
    case ACK_SENT = 3
    case HANDSHAKE_DONE = 4
    case CLOSING = 5
    case CLOSED = 6
}

final class RTMPSocket: NSObject, NSStreamDelegate {
    static let sigSize:Int = 1536
    static let defaultChunkSize:Int = 128
    static let defaultBufferSize:Int = 1024

    var readyState:RTMPSocketReadyState = RTMPSocketReadyState.INITIALIZED {
        didSet {
            delegate?.didSetReadyState(self, readyState: readyState)
        }
    }

    var objectEncoding:UInt8 = RTMPConnection.defaultObjectEncoding
    var chunkSizeC:Int = RTMPSocket.defaultChunkSize
    var chunkSizeS:Int = RTMPSocket.defaultChunkSize
    var bufferSize:Int = RTMPSocket.defaultBufferSize
    weak var delegate:RTMPSocketDelegate? = nil

    private var running:Bool = false
    private var timestamp:NSTimeInterval = 0
    private var inputBuffer:[UInt8] = []
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
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),{
            self.initConnection(host, port: port)
        })
    }

    func close() {
        readyState = RTMPSocketReadyState.CLOSING

        inputStream!.delegate = nil
        inputStream!.removeFromRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
        inputStream!.close()
        
        outputStream!.delegate = nil
        outputStream!.removeFromRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
        outputStream!.close()

        inputStream = nil
        outputStream = nil

        running = false
        readyState = RTMPSocketReadyState.CLOSED
    }

    func stream(aStream: NSStream, handleEvent eventCode: NSStreamEvent) {
        switch eventCode {
        case NSStreamEvent.OpenCompleted:
            if (inputStream!.streamStatus == NSStreamStatus.Open &&
                outputStream!.streamStatus == NSStreamStatus.Open) {
                handleEvent()
            }
        case NSStreamEvent.HasBytesAvailable:
            if (aStream == inputStream) {
                doInputProcess()
            }
        case NSStreamEvent.EndEncountered:
            break
        case NSStreamEvent.None:
            break
        case NSStreamEvent.ErrorOccurred:
            close()
            break
        default:
            break
        }
    }

    private func initConnection(host:CFString, port:UInt32) {
        var readStream:Unmanaged<CFReadStream>?
        var writeStream:Unmanaged<CFWriteStream>?

        timestamp = 0
        chunkSizeS = RTMPSocket.defaultChunkSize
        chunkSizeC = RTMPSocket.defaultChunkSize
        bufferSize = RTMPSocket.defaultBufferSize
        inputBuffer.removeAll(keepCapacity: false)

        CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault, host, port, &readStream, &writeStream)
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

    private func doInputProcess() {
        var buffer:[UInt8] = [UInt8](count: bufferSize, repeatedValue: 0)
        let length:Int = inputStream!.read(&buffer, maxLength: bufferSize)
        if 0 < length {
            inputBuffer += buffer
        }
        handleEvent()
    }

    private func doOutputProcess(bytes:[UInt8]) {
        dispatch_async(outputQueue) {
            if (RTMPSocketReadyState.HANDSHAKE_DONE.rawValue < self.readyState.rawValue) {
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
            }
        }
    }

    private func handleEvent() {
        switch readyState {
        case .INITIALIZED:
            timestamp = NSDate().timeIntervalSince1970
            let c1packet:ByteArray = ByteArray()
            c1packet.write(Int32(timestamp))
            c1packet.write([0x00, 0x00, 0x00, 0x00])
            for i in 0..<RTMPSocket.sigSize - 8 {
                c1packet.writeUInt8(UInt8(arc4random_uniform(0xff)))
            }
            doWrite([objectEncoding])
            doWrite(c1packet.bytes)
            readyState = RTMPSocketReadyState.VERSION_SENT
            break
        case .VERSION_SENT:
            if (inputBuffer.count < RTMPSocket.sigSize + 1) {
                break
            }
            let c2packet:ByteArray = ByteArray()
            c2packet.write(Array(inputBuffer[1...4]))
            c2packet.write(Int32(NSDate().timeIntervalSince1970 - timestamp))
            c2packet.write(Array(inputBuffer[9...RTMPSocket.sigSize]))
            doWrite(c2packet.bytes)
            inputBuffer = Array(inputBuffer[RTMPSocket.sigSize + 1..<inputBuffer.count])
            readyState = RTMPSocketReadyState.ACK_SENT
            break
        case .ACK_SENT:
            if (inputBuffer.count < RTMPSocket.sigSize) {
                break
            }
            let s2packet:[UInt8] = Array(inputBuffer[0..<RTMPSocket.sigSize])
            inputBuffer.removeAll(keepCapacity: false)
            readyState = RTMPSocketReadyState.HANDSHAKE_DONE
            break
        case .HANDSHAKE_DONE:
            if (inputBuffer.isEmpty){
                break
            }
            delegate?.listen(self, bytes: inputBuffer)
            inputBuffer.removeAll(keepCapacity: false)
            break
        default:
            break
        }
    }
}
