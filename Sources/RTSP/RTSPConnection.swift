import Foundation

class RTSPConnection: NSObject {
    private lazy var socket:RTSPSocket = {
        let socket:RTSPSocket = RTSPSocket()
        socket.delegate = self
        return socket
    }()

    var userAgent:String = "lf.swift"
    private var sequence:Int = 0

    func options(uri:String) {
        sequence += 1
        var request:RTSPRequest = RTSPRequest()
        request.method = "OPTIONS"
        request.uri = uri
        request.headerFields = [
            "CSeq": "\(sequence)",
            "User-Agent": userAgent,
        ]
        socket.doOutput(request)
    }
}

// MARK: RTSPSocketDelegate
extension RTSPConnection: RTSPSocketDelegate {
    func listen(response: RTSPResponse) {
    }
}
