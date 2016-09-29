import Foundation

extension Mirror {
    var description:String {
        var data:[String] = []
        if let superclassMirror:Mirror = superclassMirror {
            for child in superclassMirror.children {
                guard let label:String = child.label else {
                    continue
                }
                data.append("\(label):\(child.value)")
            }
        }
        for child in children {
            guard let label:String = child.label else {
                continue
            }
            data.append("\(label):\(child.value)")
        }
        return "\(subjectType){\(data.joined(separator: ","))}"
    }
}

// MARK: -
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

    init(bytes:[UInt8]) {
        self = bytes.withUnsafeBufferPointer {
            $0.baseAddress!.withMemoryRebound(to: Self.self, capacity: 1) {
                $0.pointee
            }
        }
    }
}
