import Foundation

enum ByteArrayError: ErrorType {
    case EOF
    case Parse
}

final class ByteArray {
    static let sizeOfInt8:Int = 1
    static let sizeOfInt16:Int = 2
    static let sizeOfInt24:Int = 3
    static let sizeOfInt32:Int = 4
    static let sizeOfFloat:Int = 4
    static let sizeOfDouble:Int = 8

    private(set) var bytes:[UInt8] = []

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

    var position:Int = 0

    var bytesAvailable:Int {
        return bytes.count - position
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

    func readUInt8() throws -> UInt8 {
        guard ByteArray.sizeOfInt8 <= bytesAvailable else {
            throw ByteArrayError.EOF
        }
        return bytes[position++]
    }

    func writeUInt8(value:UInt8) -> ByteArray {
        bytes.append(value)
        position = bytes.count
        return self
    }

    func readInt8() throws -> Int8 {
        guard ByteArray.sizeOfInt8 <= bytesAvailable else {
            throw ByteArrayError.EOF
        }
        return Int8(bitPattern: UInt8(bytes[position++]))
    }

    func writeInt8(value:Int8) -> ByteArray {
        bytes.append(UInt8(bitPattern: value))
        position = bytes.count
        return self
    }

    func readUInt16() throws -> UInt16 {
        guard ByteArray.sizeOfInt16 <= bytesAvailable else {
            throw ByteArrayError.EOF
        }
        position += ByteArray.sizeOfInt16
        return UInt16(bytes: Array(bytes[position - ByteArray.sizeOfInt16..<position])).bigEndian
    }

    func writeUInt16(value:UInt16) -> ByteArray {
        bytes += value.bigEndian.bytes
        position = bytes.count
        return self
    }

    func readInt16() throws -> Int16 {
        guard ByteArray.sizeOfInt16 <= bytesAvailable else {
            throw ByteArrayError.EOF
        }
        position += ByteArray.sizeOfInt16
        return Int16(bytes: Array(bytes[position - ByteArray.sizeOfInt16..<position])).bigEndian
    }

    func writeInt16(value:Int16) -> ByteArray {
        bytes += value.bigEndian.bytes
        position = bytes.count
        return self
    }

    func readUInt24() throws -> UInt32 {
        guard ByteArray.sizeOfInt24 <= bytesAvailable else {
            throw ByteArrayError.EOF
        }
        return (UInt32(bytes[position++]) << 16) | (UInt32(bytes[position++]) << 8) | UInt32(bytes[position++])
    }

    func writeUInt24(value:UInt32) -> ByteArray {
        bytes += Array(value.bigEndian.bytes[1...ByteArray.sizeOfInt24])
        position = bytes.count
        return self
    }

    func readUInt32() throws -> UInt32 {
        guard ByteArray.sizeOfInt32 <= bytesAvailable else {
            throw ByteArrayError.EOF
        }
        position += ByteArray.sizeOfInt32
        return UInt32(bytes: Array(bytes[position - ByteArray.sizeOfInt32..<position])).bigEndian
    }

    func writeUInt32(value:UInt32) -> ByteArray {
        bytes += value.bigEndian.bytes
        position = bytes.count
        return self
    }

    func readInt32() throws -> Int32 {
        guard ByteArray.sizeOfInt32 <= bytesAvailable else {
            throw ByteArrayError.EOF
        }
        position += ByteArray.sizeOfInt32
        return Int32(bytes: Array(bytes[position - ByteArray.sizeOfInt32..<position])).bigEndian
    }

    func writeInt32(value:Int32) -> ByteArray {
        bytes += value.bigEndian.bytes
        position = bytes.count
        return self
    }

    func readDouble() throws -> Double {
        guard ByteArray.sizeOfDouble <= bytesAvailable else {
            throw ByteArrayError.EOF
        }
        position += ByteArray.sizeOfDouble
        return Double(bytes: Array(bytes[position - ByteArray.sizeOfDouble..<position]))
    }

    func writeDouble(value:Double) -> ByteArray {
        bytes += value.bytes
        position = bytes.count
        return self
    }

    func readFloat() throws -> Float {
        guard ByteArray.sizeOfFloat <= bytesAvailable else {
            throw ByteArrayError.EOF
        }
        position += ByteArray.sizeOfFloat
        return Float(bytes: Array(bytes[position - ByteArray.sizeOfFloat..<position]))
    }

    func writeFloat(value:Float) -> ByteArray {
        bytes += value.bytes
        position = bytes.count
        return self
    }

    func readUTF8(length:Int) throws -> String {
        guard length <= bytesAvailable else {
            throw ByteArrayError.EOF
        }
        position += length
        guard let result:String = String(bytes: Array(bytes[position - length..<position]), encoding: NSUTF8StringEncoding) else {
            throw ByteArrayError.Parse
        }
        return result
    }

    func writeUTF8(value:String) -> ByteArray {
        bytes += [UInt8](value.utf8)
        position = bytes.count
        return self
    }

    func readUInt8(length:Int) throws -> [UInt8] {
        guard length <= bytesAvailable else {
            throw ByteArrayError.EOF
        }
        position += length
        return Array(bytes[position - length..<position])
    }

    func writeUInt8(value:[UInt8]) -> ByteArray {
        bytes += value
        position = bytes.count
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

// MARK: - CustomStringConvertible
extension ByteArray: CustomStringConvertible {
    var description:String {
        return bytes.description
    }
}
