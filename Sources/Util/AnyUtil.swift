import Foundation

final class AnyUtil {
    static func isZero(_ value: Any) -> Bool {
        if let value: Int = value as? Int {
            return value == 0
        }
        if let value: Double = value as? Double {
            return value == 0
        }
        return false
    }
}
