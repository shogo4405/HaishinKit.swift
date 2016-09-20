import Foundation

protocol HTTPRequestCompatible: BytesConvertible {
    var uri:String { get set }
    var method:String { get set }
    var version:String { get set }
    var headerFields:[String: String] { get set }
}

extension HTTPRequestCompatible {

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
            return [UInt8](lines.joined(separator: "\r\n").utf8)
        }
        set {
            var count:Int = 0
            var lines:[String] = []
            let bytes:[ArraySlice<UInt8>] = newValue.split(separator: HTTPRequest.separator)
            for i in 0..<bytes.count {
                count += bytes[i].count + 1
                guard let line:String = String(bytes: Array(bytes[i]), encoding: String.Encoding.utf8) else {
                    continue
                }
                lines.append(line.trimmingCharacters(in: CharacterSet.newlines))
                if (bytes.last!.isEmpty) {
                    break
                }
            }
            let first:[String] = lines.first!.components(separatedBy: " ")
            method = first[0]
            uri = first[1]
            version = first[2]
            for i in 1..<lines.count {
                if (lines[i].isEmpty) {
                    continue
                }
                let pairs:[String] = lines[i].components(separatedBy: ": ")
                headerFields[pairs[0]] = pairs[1]
            }
        }
    }
}

// MARK: -
struct HTTPRequest: HTTPRequestCompatible {
    static let separator:UInt8 = 0x0a

    var uri:String = "/"
    var method:String = ""
    var version:String = HTTPVersion.version11.description
    var headerFields:[String: String] = [:]

    init() {
    }

    init?(bytes:[UInt8]) {
        self.bytes = bytes
    }
}
