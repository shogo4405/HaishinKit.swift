import Foundation

public protocol RTMPSocketFactory {
    var supportedSchemes: Set<String> { get }

    func createSocket(forScheme scheme: String) -> RTMPSocketCompatible
}

public class DefaultRTMPSocketFactory: RTMPSocketFactory {
    public let supportedSchemes: Set<String> = ["rtmp", "rtmps", "rtmpt", "rtmpts"]

    static public let shared = DefaultRTMPSocketFactory()

    private init() {}

    public func createSocket(forScheme scheme: String) -> RTMPSocketCompatible {
        var socket: RTMPSocketCompatible

        switch scheme {
        case "rtmpt", "rtmpts":
            socket = RTMPTSocket()
        default:
            socket = RTMPSocket()
        }
        socket.securityLevel = scheme == "rtmps" || scheme == "rtmpts"  ? .negotiatedSSL : .none
        return socket
    }
}
