import Foundation

// MARK: NetClientDelegate
@objc protocol NetClientDelegate: class {
    optional func client(inputBuffer client:NetClient)
    optional func client(didAccepetConnection client:NetClient)
}

// MARK: -
final class NetClient: NetSocket {
    static let defaultBufferSize:Int = 8192

    weak var delegate:NetClientDelegate?
    private(set) var service:NSNetService?

    init(service:NSNetService, inputStream:NSInputStream, outputStream:NSOutputStream) {
        super.init()
        self.service = service
        self.inputStream = inputStream
        self.outputStream = outputStream
    }

    func acceptConnection() {
        dispatch_async(networkQueue) {
            self.initConnection()
            self.delegate?.client?(didAccepetConnection: self)
        }
    }

    override func listen() {
        delegate?.client?(inputBuffer: self)
    }
}
