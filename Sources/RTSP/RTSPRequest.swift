import Foundation

public struct RTSPRequest: HTTPRequestCompatible {
    public var uri:String = "/"
    public var method:String = ""
    public var version:String = "RTSP/1.0"
    public var headerFields:[String: String] = [:]
    public var body:Data?

    public init() {
    }

    init?(bytes:[UInt8]) {
        self.bytes = bytes
    }
}
