import Foundation

extension Mirror {
    var description:String {
        var data:[String] = []
        if let superclassMirror:Mirror = superclassMirror() {
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
        return "\(subjectType){\(data.joinWithSeparator(","))}"
    }
}

extension IntegerLiteralConvertible {
    var bytes:[UInt8] {
        var value:Self = self
        return withUnsafePointer(&value) {
            Array(UnsafeBufferPointer(start: UnsafePointer<UInt8>($0), count: sizeof(Self.self)))
        }
    }

    init(bytes:[UInt8]) {
        self = bytes.withUnsafeBufferPointer {
            return UnsafePointer<`Self`>($0.baseAddress).memory
        }
    }
}
