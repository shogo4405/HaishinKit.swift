import Foundation

protocol HTTPResponseCompatible: BytesConvertible, CustomStringConvertible {
    var version:String { get set }
    var statusCode:String { get set }
    var headerFields:[String: String] { get set }
    var body:[UInt8] { get set }
}

extension HTTPResponseCompatible {

    var description:String {
        return Mirror(reflecting: self).description
    }

    var bytes:[UInt8] {
        get {
            var lines:[String] = []
            lines.append("\(version) \(statusCode)")
            for (key, value) in headerFields {
                lines.append("\(key): \(value)")
            }
            return [UInt8](lines.joined(separator: "\r\n").utf8) + HTTPResponse.separator + body
        }
        set {
            var count:Int = 0
            var lines:[String] = []
            
            let bytes:[ArraySlice<UInt8>] = newValue.split(separator: HTTPRequest.separator)
            for i in 0..<bytes.count {
                count += bytes[i].count + 1
                guard let line:String = String(bytes: Array(bytes[i]), encoding: String.Encoding.utf8)
                    , line != "\r" else {
                        break
                }
                lines.append(line.trimmingCharacters(in: CharacterSet.newlines))
            }
            
            guard let first:[String] = lines.first?.components(separatedBy: " ") else {
                return
            }
            
            version = first[0]
            statusCode = first[1]
            
            for i in 1..<lines.count {
                let pairs:[String] = lines[i].components(separatedBy: ": ")
                headerFields[pairs[0]] = pairs[1]
            }
            
            body = Array(newValue[count..<newValue.count])
        }
    }
}

// MARK: -
struct HTTPResponse: HTTPResponseCompatible {
    static let separator:[UInt8] = [0x0d, 0x0a, 0x0d, 0x0a]

    var version:String = HTTPVersion.version11.rawValue
    var statusCode:String = ""
    var headerFields:[String: String] = [:]
    var body:[UInt8] = []
}
