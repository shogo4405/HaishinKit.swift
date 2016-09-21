import Foundation

@objc protocol NetClientDelegate: class {
    @objc optional func client(inputBuffer client:NetClient)
    @objc optional func client(didAccepetConnection client:NetClient)
}

// MARK: -
final class NetClient: NetSocket {
    static let defaultBufferSize:Int = 8192

    weak var delegate:NetClientDelegate?
    private(set) var service:Foundation.NetService?

    init(service:Foundation.NetService, inputStream:InputStream, outputStream:OutputStream) {
        super.init()
        self.service = service
        self.inputStream = inputStream
        self.outputStream = outputStream
    }

    func acceptConnection() {
        networkQueue.async {
            self.initConnection()
            self.delegate?.client?(didAccepetConnection: self)
        }
    }

    override func listen() {
        delegate?.client?(inputBuffer: self)
    }
}
