import Foundation

public struct RTSPResponse: HTTPResponseCompatible {
    public var version:String = "RTSP/1.0"
    public var statusCode:String = ""
    public var headerFields:[String:String] = [:]
    public var body:Data?

    public init() {
    }

    init?(data:Data) {
        self.data = data
    }
}
