import Foundation

// MARK: - HTTPRequest
struct HTTPRequest {
    static let separator:UInt8 = 0x0a

    var uri:String?
    var method:String?
    var version:String?

    var headerFields:[String: String] = [:]
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
            method = first[0]
            uri = first[1]
            version = first[2]

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
