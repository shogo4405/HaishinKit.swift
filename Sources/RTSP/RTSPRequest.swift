import Foundation

struct RTSPRequest: HTTPRequestCompatible {
    var uri:String = "/"
    var method:String = ""
    var version:String = "RTSP/1.0"
    var headerFields:[String: String] = [:]

    init() {
    }

    init?(bytes:[UInt8]) {
        self.bytes = bytes
    }
}
