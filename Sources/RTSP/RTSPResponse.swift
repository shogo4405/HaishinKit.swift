import Foundation

struct RTSPResponse: HTTPResponseConvertible {
    var version:String = "RTSP/1.0"
    var statusCode:String = ""
    var headerFields:[String: String] = [:]
    var body:[UInt8] = []

    init() {
    }

    init?(bytes:[UInt8]) {
        self.bytes = bytes
    }
}
