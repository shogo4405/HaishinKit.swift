import Foundation

/// A struct that represents a it reports its rtmp status.
@dynamicMemberLookup
public struct RTMPStatus: Sendable {
    /// The string that represents a specific event.
    public let code: String
    /// The string that is either "status" or "error".
    public let level: String
    /// The string that is code description.
    public let description: String

    private let data: AMFObject?

    init?(_ data: AMFObject?) {
        guard
            let data,
            let code = data["code"] as? String,
            let level = data["level"] as? String else {
            return nil
        }
        self.data = data
        self.code = code
        self.level = level
        self.description = (data["description"] as? String) ?? ""
    }

    init(code: String, level: String, description: String) {
        self.code = code
        self.level = level
        self.description = description
        self.data = nil
    }

    public subscript(dynamicMember key: String) -> String? {
        guard let value = data?[key] as? String else {
            return nil
        }
        return value
    }

    public subscript(dynamicMember key: String) -> Double? {
        guard let value = data?[key] as? Double else {
            return nil
        }
        return value
    }
}
