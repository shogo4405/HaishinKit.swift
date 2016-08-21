import Foundation

enum RTSPMethod: String {
    case OPTIONS       = "OPTIONS"
    case DESCRIBE      = "DESCRIBE"
    case ANNOUNCE      = "ANNOUNCE"
    case SETUP         = "SETUP"
    case PLAY          = "PLAY"
    case PAUSE         = "PAUSE"
    case TEARDOWN      = "TEARDOWN"
    case GET_PARAMETER = "GET_PARAMETER"
    case SET_PARAMETER = "SET_PARAMETER"
    case REDIRECT      = "REDIRECT"
    case RECORD        = "RECORD"
}

// MARK: RTSPResponder
protocol RTSPResponder: class {
    func onResponse(response:RTSPResponse)
}

// MARK: -
final class RTSPLoggerResponder: RTSPResponder {
    static let instance:RTSPLoggerResponder = RTSPLoggerResponder()

    func onResponse(response:RTSPResponse) {
        logger.info("\(response)")
    }
}

// MARK: -
class RTSPConnection: NSObject {
    var userAgent:String = "lf.swift"
    private var sequence:Int = 0
    private lazy var socket:RTSPSocket = {
        let socket:RTSPSocket = RTSPSocket()
        socket.delegate = self
        return socket
    }()

    private var responders:[RTSPResponder] = []

    func doMethod(method: RTSPMethod, _ uri: String, _ headerFields:[String:String] = [:], _ responder:RTSPResponder = RTSPLoggerResponder.instance) {
        sequence += 1
        var request:RTSPRequest = RTSPRequest()
        request.uri = uri
        request.method = method.rawValue
        request.headerFields = headerFields
        request.headerFields["C-Seq"] = "\(sequence)"
        request.headerFields["User-Agent"] = userAgent
        responders.append(responder)
        socket.doOutput(request)
    }
}

// MARK: RTSPSocketDelegate
extension RTSPConnection: RTSPSocketDelegate {
    func listen(response: RTSPResponse) {
        guard let responder:RTSPResponder = responders.first else {
            return
        }
        responder.onResponse(response)
        responders.removeFirst()
    }
}
