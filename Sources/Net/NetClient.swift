import Foundation

@objc
protocol NetClientDelegate: AnyObject {
    @objc
    optional func client(inputBuffer client: NetClient)

    @objc
    optional func client(didAccepetConnection client: NetClient)

    func client(client: NetClient, isDisconnected: Bool)
}

// MARK: -
/// The NetClient class creates a two-way connection  between a NetService.
public final class NetClient: NetSocket {
    weak var delegate: (any NetClientDelegate)?

    init(inputStream: InputStream, outputStream: OutputStream) {
        super.init()
        self.inputStream = inputStream
        self.outputStream = outputStream
    }

    override public func listen() {
        delegate?.client?(inputBuffer: self)
    }

    func acceptConnection() {
        inputQueue.async {
            self.initConnection()
            self.delegate?.client?(didAccepetConnection: self)
        }
    }

    override func deinitConnection(isDisconnected: Bool) {
        super.deinitConnection(isDisconnected: isDisconnected)
        delegate?.client(client: self, isDisconnected: isDisconnected)
    }
}
