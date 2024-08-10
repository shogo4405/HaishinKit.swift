import Foundation

public struct RTMPStatus: Sendable {
    /// The string that represents a specific event.
    public let code: String
    /// The string that is either "status" or "error".
    public let level: String
    /// The string that is code description.
    public let description: String

    init?(_ data: AMFObject?) {
        guard
            let data,
            let code = data["code"] as? String,
            let level = data["level"] as? String,
            let description = data["description"] as? String else {
            return nil
        }
        self.code = code
        self.level = level
        self.description = description
    }

    init(code: String, level: String, description: String) {
        self.code = code
        self.level = level
        self.description = description
    }
}
