import Foundation

extension ExpressibleByIntegerLiteral {
    var data: Data {
        return withUnsafePointer(to: self) { value in
            return Data(bytes: UnsafeRawPointer(value), count: MemoryLayout<Self>.size)
        }
    }

    init(data: Data) {
        let diff: Int = MemoryLayout<Self>.size - data.count
        if 0 < diff {
            var buffer = Data(repeating: 0, count: diff)
            buffer.append(data)
            self = buffer.withUnsafeBytes { $0.baseAddress!.assumingMemoryBound(to: Self.self).pointee }
            return
        }
        self = data.withUnsafeBytes { $0.baseAddress!.assumingMemoryBound(to: Self.self).pointee }
    }

    init(data: Slice<Data>) {
        self.init(data: Data(data))
    }
}
