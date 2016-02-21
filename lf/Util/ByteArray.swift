import Foundation

final class ByteArray: CustomStringConvertible {
    private(set) var bytes:[UInt8] = []

    var position:Int = 0

    var length:Int {
        get {
            return bytes.count
        }
        set {
            switch true {
            case (bytes.count < newValue):
                bytes += [UInt8](count: newValue - bytes.count, repeatedValue: 0)
            case (newValue < bytes.count):
                bytes = Array(bytes[0..<newValue])
            default:
                break
            }
        }
    }

    var description:String {
        return bytes.description
    }

    subscript(i: Int) -> UInt8 {
        get {
            return bytes[i]
        }
        set {
            bytes[i] = newValue
        }
    }

    init() {
    }

    init(bytes:[UInt8]) {
        self.bytes = bytes
    }

    init(data:NSData) {
        bytes = [UInt8](count: data.length, repeatedValue: 0x00)
        data.getBytes(&bytes, length: data.length)
    }

    func readUInt8() -> UInt8 {
        return bytes[position++]
    }

    func writeUInt8(value:UInt8) -> ByteArray {
        bytes.append(value)
        return self
    }

    func readUInt8(length:Int) -> [UInt8] {
        position += length
        return Array(bytes[position - length..<position])
    }

    func writeUInt8(value:[UInt8]) -> ByteArray {
        bytes += value
        return self
    }

    func readUInt16() -> UInt16 {
        position += 2
        return UInt16(bytes: Array(bytes[position - 2..<position])).bigEndian
    }

    func readUInt24() -> UInt32 {
        return (UInt32(bytes[position++]) << 16) | (UInt32(bytes[position++]) << 8) | UInt32(bytes[position++])
    }

    func readUInt32() -> UInt32 {
        position += 4
        return UInt32(bytes: Array(bytes[position - 4..<position])).bigEndian
    }

    func write(value:Int32) -> ByteArray {
        bytes += value.bytes
        return self
    }

    func read(length:Int) -> String {
        position += length
        return String(bytes: Array(bytes[position - length..<position]), encoding: NSUTF8StringEncoding)!
    }

    func write(value:String) -> ByteArray {
        bytes += [UInt8](value.utf8)
        return self
    }

    func sequence(length:Int, lambda:(ByteArray -> Void)) {
        let r:Int = (bytes.count - position) % length
        for index in bytes.startIndex.advancedBy(position).stride(to: bytes.endIndex.advancedBy(-r), by: length) {
            lambda(ByteArray(bytes: Array(bytes[index..<index.advancedBy(length)])))
        }
        if (0 < r) {
            lambda(ByteArray(bytes: Array(bytes[bytes.endIndex - r..<bytes.endIndex])))
        }
     }

    func clear() {
        position = 0
        bytes.removeAll(keepCapacity: false)
    }

    func toUInt32() -> [UInt32] {
        let size:Int = sizeof(UInt32)
        if ((bytes.endIndex - position) % size != 0) {
            return []
        }
        var result:[UInt32] = []
        for index in bytes.startIndex.advancedBy(position).stride(to: bytes.endIndex, by: size) {
            result.append(UInt32(bytes: Array(bytes[index..<index.advancedBy(size)])))
        }
        return result
    }
}
