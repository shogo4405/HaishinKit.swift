import Foundation

// MARK: HTTPRequestConvertible
protocol HTTPRequestConvertible: BytesConvertible {
    var uri:String { get set }
    var method:String { get set }
    var version:String { get set }
    var headerFields:[String: String] { get set }
}

// MARK: -
struct HTTPRequest: HTTPRequestConvertible {
    static let separator:UInt8 = 0x0a

    var uri:String = "/"
    var method:String = ""
    var version:String = HTTPVersion.Version11.description
    var headerFields:[String: String] = [:]

    init() {
    }

    init?(bytes:[UInt8]) {
        self.bytes = bytes
    }
}

// MARK: -
extension HTTPRequestConvertible {
    
    var description:String {
        return Mirror(reflecting: self).description
    }
    
    var bytes:[UInt8] {
        get {
            var lines:[String] = ["\(method) \(uri) \(version)"]
            for (field, value) in headerFields {
                lines.append("\(field): \(value)")
            }
            lines.append("\r\n")
            return [UInt8](lines.joinWithSeparator("\r\n").utf8)
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

