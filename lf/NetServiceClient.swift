import Foundation

protocol NetServiceClientDeledate:class {
    func handleEvent(client:NetServiceClient)
}

class NetServiceClient:NSObject, NSStreamDelegate {
    static let defaultBufferSize:Int = 8192

    var inputBuffer:[UInt8] = []
    weak var delegate:NetServiceClientDeledate?
    let lockQueue:dispatch_queue_t = dispatch_queue_create("com.github.shogo4405.lf.NetServiceClient.lock", DISPATCH_QUEUE_SERIAL)

    private var inputStream:NSInputStream
    private var outputStream:NSOutputStream

    init (inputStream:NSInputStream, outputStream:NSOutputStream) {
        self.inputStream = inputStream
        self.outputStream = outputStream
    }

    func doWrite(bytes:[UInt8]) {
        dispatch_async(lockQueue) {
            var total:Int = 0
            let buffer:UnsafePointer<UInt8> = UnsafePointer<UInt8>(bytes)
            while total < bytes.count {
                let length:Int? = self.outputStream.write(buffer + total, maxLength: bytes.count - total)
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
    }

    func stream(aStream: NSStream, handleEvent eventCode: NSStreamEvent) {
        switch eventCode {
        case NSStreamEvent.None:
            break
        case NSStreamEvent.OpenCompleted:
            if (inputStream.streamStatus == NSStreamStatus.Open && outputStream.streamStatus == NSStreamStatus.Open) {
                delegate?.handleEvent(self)
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

    private func doInputProcess() {
        var buffer:[UInt8] = [UInt8](count: NetServiceClient.defaultBufferSize, repeatedValue: 0)
        let length:Int = inputStream.read(&buffer, maxLength: NetServiceClient.defaultBufferSize)
        if 0 < length {
            inputBuffer += Array(buffer[0..<length])
        }
        delegate?.handleEvent(self)
    }
}
