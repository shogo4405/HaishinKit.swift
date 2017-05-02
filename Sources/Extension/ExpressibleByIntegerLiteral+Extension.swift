import Foundation

extension ExpressibleByIntegerLiteral {
    var bytes:[UInt8] {
        var value:Self = self
        let s:Int = MemoryLayout<`Self`>.size
        return withUnsafeMutablePointer(to: &value) {
            $0.withMemoryRebound(to: UInt8.self, capacity: s) {
                Array(UnsafeBufferPointer(start: $0, count: s))
            }
        }
    }

    var data:Data {
        var value:Self = self
        return Data(buffer: UnsafeBufferPointer(start: &value, count: 1))
    }

    init(bytes:[UInt8]) {
        self = bytes.withUnsafeBufferPointer {
            $0.baseAddress!.withMemoryRebound(to: Self.self, capacity: 1) {
                $0.pointee
            }
        }
    }

    init(data:Data) {
        let diff:Int = MemoryLayout<Self>.size - data.count
        if (0 < diff) {
            var buffer:Data = Data(repeating: 0, count: diff)
            buffer.append(data)
            self = buffer.withUnsafeBytes { $0.pointee }
            return
        }
        self = data.withUnsafeBytes { $0.pointee }
    }

    init(data:MutableRangeReplaceableRandomAccessSlice<Data>) {
        self.init(data: Data(data))
    }
}
