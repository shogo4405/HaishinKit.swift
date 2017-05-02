import Foundation

protocol RTSPSocketDelegate: class {
    func listen(_ response:RTSPResponse)
}

// MARK: -
final class RTSPSocket: NetSocket {
    static let defaultPort:Int = 554

    weak var delegate:RTSPSocketDelegate?
    fileprivate var requests:[RTSPRequest] = []

    override var connected:Bool {
        didSet {
            if (connected) {
                for request in requests {
                    if (logger.isEnabledFor(level: .verbose)) {
                        logger.verbose("\(request)")
                    }
                    doOutput(bytes: request.bytes)
                }
                requests.removeAll()
            }
        }
    }

    func doOutput(_ request:RTSPRequest) {
        if (connected) {
            if (logger.isEnabledFor(level: .verbose)) {
                logger.verbose("\(request)")
            }
            doOutput(bytes: request.bytes)
            return
        }
        requests.append(request)
        guard let uri:URL = URL(string: request.uri), let host:String = uri.host else {
            return
        }
        connect(host, port: (uri as NSURL).port?.intValue ?? RTSPSocket.defaultPort)
    }

    override func listen() {
        guard let response:RTSPResponse = RTSPResponse(bytes: inputBuffer.bytes) else {
            return
        }
        if (logger.isEnabledFor(level: .verbose)) {
            logger.verbose("\(response)")
        }
        delegate?.listen(response)
        inputBuffer.removeAll()
    }

    fileprivate func connect(_ hostname:String, port:Int) {
        networkQueue.async {
            Stream.getStreamsToHost(
                withName: hostname,
                port: port,
                inputStream: &self.inputStream,
                outputStream: &self.outputStream
            )
            self.initConnection()
        }
    }
}
