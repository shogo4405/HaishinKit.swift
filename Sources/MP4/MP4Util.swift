import Foundation

struct MP4Util {
    static func string(_ value: UInt32) -> String? {
        return String(data: value.bigEndian.data, encoding: .ascii)
    }

    static func uint32(_ value: String) -> UInt32 {
        var loop = 0
        var result: UInt32 = 0
        for scalar in value.unicodeScalars {
            result |= scalar.value << (8 * loop)
            loop += 1
        }
        return result.bigEndian
    }
}
