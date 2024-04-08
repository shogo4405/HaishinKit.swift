import Foundation

extension Data {
    var bytes: [UInt8] {
        return withUnsafeBytes {
            [UInt8](UnsafeBufferPointer(start: $0, count: count))
        }
    }
}
