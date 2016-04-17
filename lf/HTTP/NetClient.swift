import Foundation

// MARK: - NetClientDelegate
@objc protocol NetClientDelegate: class {
    optional func client(inputBuffer client:NetClient)
    optional func client(didAccepetConnection client:NetClient)
    optional func client(didOpenCompleted client:NetClient)
}

// MARK: - NetClient
class NetClient: NSObject {
    static let defaultBufferSize:Int = 8192

    weak var delegate:NetClientDelegate?
    private(set) var service:NSNetService?
    private(set) var inputBuffer:[UInt8] = []
    private let lockQueue:dispatch_queue_t = dispatch_queue_create(
        "com.github.shogo4405.lf.NetServiceClient.lock", DISPATCH_QUEUE_SERIAL
    )

    private var inputStream:NSInputStream!
    private var outputStream:NSOutputStream!

    init(service: NSNetService) {
        self.service = service
        var inputStream:NSInputStream?
        var outputStream:NSOutputStream?
        NSStream.getStreamsToHostWithName(service.hostName!, port: service.port, inputStream: &inputStream, outputStream: &outputStream)
        self.inputStream = inputStream
        self.outputStream = outputStream
    }

    init(service:NSNetService, inputStream:NSInputStream, outputStream:NSOutputStream) {
        self.service = service
        self.inputStream = inputStream
        self.outputStream = outputStream
    }

    func doWrite(bytes:[UInt8]) {
        dispatch_async(lockQueue) {
            var total:Int = 0
            let buffer:UnsafePointer<UInt8> = UnsafePointer<UInt8>(bytes)
            while total < bytes.count {
                let length:Int? = self.outputStream!.write(buffer + total, maxLength: bytes.count - total)
                total += length!
            }
        }
    }

    func acceptConnection() {
        inputStream.delegate = self
        inputStream.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
        outputStream.delegate = self
        outputStream.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
        inputStream.open()
        outputStream.open()
        delegate?.client?(didAccepetConnection: self)
    }

    func disconnect() {
        inputStream.close()
        inputStream.removeFromRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
        inputStream.delegate = nil
        outputStream.close()
        outputStream.removeFromRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
        outputStream.delegate = nil
    }

    private func doInputProcess() {
        var buffer:[UInt8] = [UInt8](count: NetClient.defaultBufferSize, repeatedValue: 0)
        let length:Int = inputStream.read(&buffer, maxLength: NetClient.defaultBufferSize)
        if 0 < length {
            inputBuffer += Array(buffer[0..<length])
        }
        if (!inputBuffer.isEmpty) {
            delegate?.client?(inputBuffer: self)
        }
    }
}

// MARK: NSStreamDelegate
extension NetClient: NSStreamDelegate {
    func stream(aStream: NSStream, handleEvent eventCode: NSStreamEvent) {
        switch eventCode {
        case NSStreamEvent.None:
            break
        case NSStreamEvent.OpenCompleted:
            if (inputStream.streamStatus == NSStreamStatus.Open && outputStream.streamStatus == NSStreamStatus.Open) {
                delegate?.client?(didOpenCompleted: self)
            }
        case NSStreamEvent.HasSpaceAvailable:
            break
        case NSStreamEvent.HasBytesAvailable:
            if (aStream == inputStream) {
                doInputProcess()
            }
        case NSStreamEvent.ErrorOccurred:
            break
        case NSStreamEvent.EndEncountered:
            break
        default:
            break
        }
    }
}
