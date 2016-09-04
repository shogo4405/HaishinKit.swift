import Foundation

@objc protocol NetClientDelegate: class {
    @objc optional func client(inputBuffer client:NetClient)
    @objc optional func client(didAccepetConnection client:NetClient)
}

// MARK: -
final class NetClient: NetSocket {
    static internal let defaultBufferSize:Int = 8192

    internal weak var delegate:NetClientDelegate?
    internal fileprivate(set) var service:Foundation.NetService?

    internal init(service:Foundation.NetService, inputStream:InputStream, outputStream:OutputStream) {
        super.init()
        self.service = service
        self.inputStream = inputStream
        self.outputStream = outputStream
    }

    internal func acceptConnection() {
        networkQueue.async {
            self.initConnection()
            self.delegate?.client?(didAccepetConnection: self)
        }
    }

    override internal func listen() {
        delegate?.client?(inputBuffer: self)
    }
}
