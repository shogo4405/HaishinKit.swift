import Foundation

// MARK: - HTTPRequest
struct HTTPResponse {
    static let separator:[UInt8] = [0x0d, 0x0a, 0x0d, 0x0a]

    var version:HTTPVersion = .Version11
    var statusCode:HTTPStatusCode = .OK
    var headerFields:[String: String] = [:]
    var body:[UInt8] = []
}

// MARK: CustomStringConvertible
extension HTTPResponse: CustomStringConvertible {
    var description:String {
        return Mirror(reflecting: self).description
    }
}

// MARK: BytesConvertible
extension HTTPResponse: BytesConvertible {
    var bytes:[UInt8] {
        get {
            var lines:[String] = []
            lines.append("\(version) \(statusCode)")
            for (key, value) in headerFields {
                lines.append("\(key): \(value)")
            }
            return [UInt8](lines.joinWithSeparator("\r\n").utf8) + HTTPResponse.separator + body
        }
        set {
        }
    }
}

