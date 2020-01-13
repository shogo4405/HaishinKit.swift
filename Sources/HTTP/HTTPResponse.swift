import Foundation

protocol HTTPResponseCompatible: CustomDebugStringConvertible {
    var version: String { get set }
    var statusCode: String { get set }
    var headerFields: [String: String] { get set }
    var body: Data? { get set }
}

extension HTTPResponseCompatible {
    // MARK: CustomDebugStringConvertible
    public var debugDescription: String {
        Mirror(reflecting: self).debugDescription
    }
}

extension HTTPResponseCompatible {
    public var data: Data {
        get {
            var data = Data()
            var lines: [String] = []
            lines.append("\(version) \(statusCode)")
            for (key, value) in headerFields {
                lines.append("\(key): \(value)")
            }
            data.append(contentsOf: lines.joined(separator: "\r\n").utf8)
            data.append(contentsOf: HTTPResponse.separator)
            if let body = body {
                data.append(body)
            }
            return data
        }
        set {
            var count: Int = 0
            var lines: [String] = []
            let bytes: [Data.SubSequence] = newValue.split(separator: HTTPRequest.separator)
            for i in 0..<bytes.count {
                count += bytes[i].count + 1
                guard let line = String(bytes: Array(bytes[i]), encoding: .utf8), line != "\r" else {
                    break
                }
                lines.append(line.trimmingCharacters(in: .newlines))
            }

            guard let first: [String] = lines.first?.components(separatedBy: " ") else {
                return
            }

            version = first[0]
            statusCode = first[1]

            for i in 1..<lines.count {
                let pairs: [String] = lines[i].components(separatedBy: ": ")
                headerFields[pairs[0]] = pairs[1]
            }

            body = Data(newValue[count..<newValue.count])
        }
    }
}

// MARK: -
public struct HTTPResponse: HTTPResponseCompatible, ExpressibleByDictionaryLiteral {
    public typealias Key = String
    public typealias Value = String

    static let separator: [UInt8] = [0x0d, 0x0a, 0x0d, 0x0a]

    public var version: String = HTTPVersion.version11.rawValue
    public var statusCode: String = ""
    public var headerFields: [String: String] = [:]
    public var body: Data?

    public init(dictionaryLiteral elements: (Key, Value)...) {
        elements.forEach {
            headerFields[$0] = $1
        }
    }
}
