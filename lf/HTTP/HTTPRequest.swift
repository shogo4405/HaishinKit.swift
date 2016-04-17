import Foundation

// MARK: - HTTPRequest
struct HTTPRequest {
    static let separator:UInt8 = 0x0a

    var uri:String = "/"
    var method:HTTPMethod = .UNKOWN
    var version:HTTPVersion = .Unkown
    var headerFields:[String: String] = [:]

    init?(bytes:[UInt8]) {
        self.bytes = bytes
        if (method == .UNKOWN || version == .Unkown) {
            return nil
        }
    }
}

// MARK: CustomStringConvertible
extension HTTPRequest: CustomStringConvertible {
    var description:String {
        return Mirror(reflecting: self).description
    }
}

// MARK: BytesConvertible
extension HTTPRequest: BytesConvertible {
    var bytes:[UInt8] {
        get {
            return []
        }
        set {
            var count:Int = 0
            var lines:[String] = []
            let bytes:[ArraySlice<UInt8>] = newValue.split(HTTPRequest.separator)
            for i in 0..<bytes.count {
                count += bytes[i].count + 1
                guard let line:String = String(bytes: Array(bytes[i]), encoding: NSUTF8StringEncoding) else {
                    continue
                }
                lines.append(line.stringByTrimmingCharactersInSet(NSCharacterSet.newlineCharacterSet()))
                if (bytes.last!.isEmpty) {
                    break
                }
            }

            let first:[String] = lines.first!.componentsSeparatedByString(" ")
            method = HTTPMethod(rawValue: first[0]) ?? .UNKOWN
            uri = first[1]
            version = HTTPVersion(rawValue: first[2]) ?? .Unkown

            for i in 1..<lines.count {
                if (lines[i].isEmpty) {
                    continue
                }
                let pairs:[String] = lines[i].componentsSeparatedByString(": ")
                headerFields[pairs[0]] = pairs[1]
            }
        }
    }
}
