import Foundation

struct RTSPRequest: HTTPRequestConvertible {
    internal var uri:String = "/"
    internal var method:String = ""
    internal var version:String = "RTSP/1.0"
    internal var headerFields:[String: String] = [:]

    internal init() {
    }

    internal init?(bytes:[UInt8]) {
        self.bytes = bytes
    }
}
