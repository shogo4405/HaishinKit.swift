import Foundation

struct FilenameUtil {
    static func fileName(resourceName: String?) -> String? {
        guard var result = resourceName else {
            return nil
        }
        if let value = result.split(separator: "?").first {
            result = String(value)
        }
        if let value = result.split(separator: "/").last {
            result = String(value)
        }
        if result.count < Int(FILENAME_MAX) {
            return result
        }
        return String(result[..<result.index(result.startIndex, offsetBy: Int(FILENAME_MAX))])
    }
}
