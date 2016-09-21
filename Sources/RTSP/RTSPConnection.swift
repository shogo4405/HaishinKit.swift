import Foundation

enum RTSPMethod: String {
    case options      = "OPTIONS"
    case describe     = "DESCRIBE"
    case announce     = "ANNOUNCE"
    case setup        = "SETUP"
    case play         = "PLAY"
    case pause        = "PAUSE"
    case teardown     = "TEARDOWN"
    case getParameter = "GET_PARAMETER"
    case setParameter = "SET_PARAMETER"
    case redirect     = "REDIRECT"
    case record       = "RECORD"
}

protocol RTSPResponder: class {
    func on(response:RTSPResponse)
}

// MARK: -
final class RTSPNullResponder: RTSPResponder {
    static let instance:RTSPNullResponder = RTSPNullResponder()

    func on(response:RTSPResponse) {
    }
}

// MARK: -
class RTSPConnection: NSObject {
    static let defaultRTPPort:Int32 = 8000

    var userAgent:String = "lf.swift"

    fileprivate var sequence:Int = 0
    fileprivate lazy var socket:RTSPSocket = {
        let socket:RTSPSocket = RTSPSocket()
        socket.delegate = self
        return socket
    }()

    fileprivate var responders:[RTSPResponder] = []

    func doMethod(_ method: RTSPMethod, _ uri: String, _ responder:RTSPResponder = RTSPNullResponder.instance, _ headerFields:[String:String] = [:]) {
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

extension RTSPConnection: RTSPSocketDelegate {
    // MARK: RTSPSocketDelegate
    func listen(_ response: RTSPResponse) {
        guard let responder:RTSPResponder = responders.first else {
            return
        }
        responder.on(response: response)
        responders.removeFirst()
    }
}
