import XCGLogger
import Foundation

// MARK: RTMPSocketDelegate
protocol RTMPSocketDelegate: IEventDispatcher {
    func listen(socket: RTMPSocket, bytes:[UInt8])
    func didSetReadyState(socket: RTMPSocket, readyState:RTMPSocket.ReadyState)
}

// MARK: - RTMPSocket
final class RTMPSocket: NSObject {

    enum ReadyState:UInt8 {
        case Initialized = 1
        case VersionSent = 2
        case AckSent = 3
        case HandshakeDone = 4
        case Closing = 5
        case Closed = 6
    }

    static let sigSize:Int = 1536
    static let protocolVersion:UInt8 = 3
    static let defaultBufferSize:Int = 1024

    var readyState:ReadyState = .Initialized {
        didSet {
            delegate?.didSetReadyState(self, readyState: readyState)
        }
    }

    var inputBuffer:[UInt8] = []
    var chunkSizeC:Int = RTMPChunk.defaultSize
    var chunkSizeS:Int = RTMPChunk.defaultSize
    var bufferSize:Int = RTMPSocket.defaultBufferSize
    var objectEncoding:UInt8 = RTMPConnection.defaultObjectEncoding
    weak var delegate:RTMPSocketDelegate? = nil
    private(set) var totalBytesIn:Int = 0
    private(set) var totalBytesOut:Int = 0
    private(set) var timestamp:NSTimeInterval = 0

    private var running:Bool = false
    private var inputStream:NSInputStream? = nil
    private var outputStream:NSOutputStream? = nil
    private var outputQueue:dispatch_queue_t = dispatch_queue_create(
        "com.github.shogo4405.lf.RTMPSocket.network", DISPATCH_QUEUE_SERIAL
    )

    override init() {
        super.init()
    }

    func doWrite(bytes:[UInt8]) {
        doOutputProcess(bytes)
    }

    func doWrite(chunk:RTMPChunk) {
        logger.verbose(chunk.description)
        let chunks:[[UInt8]] = chunk.split(chunkSizeS)
        for chunk in chunks {
            doWrite(chunk)
        }
    }

    func connect(hostname:String, port:Int) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
            self.initConnection(hostname, port: port)
        })
    }

    func close(disconnect:Bool) {

        if (ReadyState.Closing.rawValue <= readyState.rawValue) {
            return
        }

        var data:ASObject? = nil
        if (disconnect) {
            data = (readyState == ReadyState.HandshakeDone) ?
                RTMPConnection.Code.ConnectClosed.data("") : RTMPConnection.Code.ConnectFailed.data("")
        }

        readyState = .Closing

        inputStream?.delegate = nil
        inputStream?.removeFromRunLoop(.currentRunLoop(), forMode: NSDefaultRunLoopMode)
        inputStream?.close()

        outputStream?.delegate = nil
        outputStream?.removeFromRunLoop(.currentRunLoop(), forMode: NSDefaultRunLoopMode)
        outputStream?.close()

        inputStream = nil
        outputStream = nil

        running = false
        readyState = .Closed

        if let data:ASObject = data {
            delegate?.dispatchEventWith(Event.RTMP_STATUS, bubbles: false, data: data)
        }
    }

    private func initConnection(hostname:String, port:Int) {
        readyState = .Initialized

        timestamp = 0
        chunkSizeS = RTMPChunk.defaultSize
        chunkSizeC = RTMPChunk.defaultSize
        bufferSize = RTMPSocket.defaultBufferSize
        totalBytesIn = 0
        totalBytesOut = 0
        inputBuffer.removeAll(keepCapacity: false)

        NSStream.getStreamsToHostWithName(hostname, port: port, inputStream: &inputStream, outputStream: &outputStream)
        guard let inputStream:NSInputStream = inputStream, outputStream:NSOutputStream = outputStream else {
            return
        }

        inputStream.delegate = self
        inputStream.scheduleInRunLoop(.currentRunLoop(), forMode: NSDefaultRunLoopMode)

        outputStream.delegate = self
        outputStream.scheduleInRunLoop(.currentRunLoop(), forMode: NSDefaultRunLoopMode)

        inputStream.open()
        outputStream.open()

        running = true
        while (running) {
            NSRunLoop.currentRunLoop().runMode(NSDefaultRunLoopMode, beforeDate: NSDate.distantFuture() )
        }
    }

    private func doInputProcess() {
        var buffer:[UInt8] = [UInt8](count: bufferSize, repeatedValue: 0)
        let length:Int = inputStream!.read(&buffer, maxLength: bufferSize)
        if 0 < length {
            inputBuffer += Array(buffer[0..<length])
            totalBytesIn += length
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
                    self.close(true)
                    break
                }
                total += length!
                self.totalBytesOut += length!
            }
        }
    }

    private func handleEvent() {
        switch readyState {
        case .Initialized:
            timestamp = NSDate().timeIntervalSince1970
            let c1packet:ByteArray = ByteArray()
            c1packet.writeInt32(Int32(timestamp))
            c1packet.writeBytes([0x00, 0x00, 0x00, 0x00])
            for _ in 0..<RTMPSocket.sigSize - 8 {
                c1packet.writeUInt8(UInt8(arc4random_uniform(0xff)))
            }
            doWrite([RTMPSocket.protocolVersion])
            doWrite(c1packet.bytes)
            readyState = .VersionSent
        case .VersionSent:
            if (inputBuffer.count < RTMPSocket.sigSize + 1) {
                break
            }
            let c2packet:ByteArray = ByteArray()
            c2packet.writeBytes(Array(inputBuffer[1...4]))
            c2packet.writeInt32(Int32(NSDate().timeIntervalSince1970 - timestamp))
            c2packet.writeBytes(Array(inputBuffer[9...RTMPSocket.sigSize]))
            doWrite(c2packet.bytes)
            inputBuffer = Array(inputBuffer[RTMPSocket.sigSize + 1..<inputBuffer.count])
            readyState = .AckSent
        case .AckSent:
            if (inputBuffer.count < RTMPSocket.sigSize) {
                break
            }
            inputBuffer.removeAll(keepCapacity: false)
            readyState = .HandshakeDone
        case .HandshakeDone:
            if (inputBuffer.isEmpty){
                break
            }
            let bytes:[UInt8] = inputBuffer
            inputBuffer.removeAll(keepCapacity: false)
            delegate?.listen(self, bytes: bytes)
        default:
            break
        }
    }
}

// MARK: - NSStreamDelegate
extension RTMPSocket: NSStreamDelegate {
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
            close(true)
        case NSStreamEvent.EndEncountered:
            break
        default:
            break
        }
    }
}
