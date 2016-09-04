import Foundation

struct RTSPResponse: HTTPResponseConvertible {
    internal var version:String = "RTSP/1.0"
    internal var statusCode:String = ""
    internal var headerFields:[String: String] = [:]
    internal var body:[UInt8] = []

    internal init() {
    }

    internal init?(bytes:[UInt8]) {
        self.bytes = bytes
    }
}
