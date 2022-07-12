import Foundation

protocol HTTPRequestCompatible: CustomStringConvertible {
    var uri: String { get set }
    var method: String { get set }
    var version: String { get set }
    var headerFields: [String: String] { get set }
    var body: Data? { get set }
}

extension HTTPRequestCompatible {
    // MARK: CustomStringConvertible
    public var description: String {
        Mirror(reflecting: self).debugDescription
    }
}

extension HTTPRequestCompatible {
    var data: Data {
        get {
            var data = Data()
            var lines: [String] = ["\(method) \(uri) \(version)"]
            for (field, value) in headerFields {
                lines.append("\(field): \(value)")
            }
            data.append(contentsOf: lines.joined(separator: "\r\n").utf8)
            return data
        }
        set {
            var lines: [String] = []
            let bytes: [Data.SubSequence] = newValue.split(separator: HTTPRequest.separator)
            for i in 0..<bytes.count {
                guard let line = String(bytes: [UInt8](bytes[i]), encoding: .utf8) else {
                    continue
                }
                let newLine: String = line.trimmingCharacters(in: .newlines)
                if newLine.isEmpty {
                    body = Data(bytes[i + 1..<bytes.count].joined(separator: [HTTPRequest.separator]))
                    break
                }
                lines.append(newLine)
            }

            guard let first: [String] = lines.first?.components(separatedBy: " "), first.count >= 3 else {
                return
            }

            method = first[0]
            uri = first[1]
            version = first[2]
            for i in 1..<lines.count {
                if lines[i].isEmpty {
                    continue
                }
                let pairs: [String] = lines[i].components(separatedBy: ": ")
                headerFields[pairs[0]] = pairs[1]
            }
        }
    }
}

// MARK: -
/// A URL load request.
public struct HTTPRequest: HTTPRequestCompatible {
    /// The separator value is 0x0a.
    public static let separator: UInt8 = 0x0a
    /// Specifies the uri to request.
    public var uri: String = "/"
    /// Specifies the http method.
    public var method: String = ""
    /// Specifies the version of  the HTTP.
    public var version: String = HTTPVersion.version11.description
    /// Specifies the header field.
    public var headerFields: [String: String] = [:]
    /// Specifies the http body.
    public var body: Data?

    /// Creates a new request with body of data.
    init?(data: Data) {
        self.data = data
    }
}
