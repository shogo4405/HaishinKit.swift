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
        var data = [UInt8](repeating: 0, count: MemoryLayout<`Self`>.size)
        data.withUnsafeMutableBufferPointer {
            UnsafeMutableRawPointer($0.baseAddress!).storeBytes(of: self, as: Self.self)
        }
        return data
    }

    init(bytes:[UInt8]) {
        self = bytes.withUnsafeBufferPointer {
            UnsafeRawPointer($0.baseAddress!).load(as: Self.self)
        }
    }
}
