import Foundation

// MARK: RTSPSocketDelegate
protocol RTSPSocketDelegate: class {
    func listen(response:RTSPResponse)
}

// MARK: -
final class RTSPSocket: NetSocket {
    static let defaultPort:Int = 554

    weak var delegate:RTSPSocketDelegate?
    private var requests:[RTSPRequest] = []

    override var connected:Bool {
        didSet {
            if (connected) {
                for request in requests {
                    if (logger.isEnabledForLogLevel(.Verbose)) {
                        logger.verbose("\(request)")
                    }
                    doOutput(bytes: request.bytes)
                }
                requests.removeAll()
            }
        }
    }

    func doOutput(request:RTSPRequest) {
        if (connected) {
            if (logger.isEnabledForLogLevel(.Verbose)) {
                logger.verbose("\(request)")
            }
            doOutput(bytes: request.bytes)
            return
        }
        requests.append(request)
        guard let uri:NSURL = NSURL(string: request.uri), host:String = uri.host else {
            return
        }
        connect(host, port: uri.port?.integerValue ?? RTSPSocket.defaultPort)
    }

    override func listen() {
        guard let response:RTSPResponse = RTSPResponse(bytes: inputBuffer) else {
            return
        }
        if (logger.isEnabledForLogLevel(.Verbose)) {
            logger.verbose("\(response)")
        }
        delegate?.listen(response)
        inputBuffer.removeAll()
    }

    private func connect(hostname:String, port:Int) {
        dispatch_async(networkQueue) {
            NSStream.getStreamsToHostWithName(
                hostname,
                port: port,
                inputStream: &self.inputStream,
                outputStream: &self.outputStream
            )
            self.initConnection()
        }
    }
}
