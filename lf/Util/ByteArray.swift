import Foundation

public enum ByteArrayError: ErrorType {
    case EOF
    case Parse
}

final public class ByteArray {
    static let sizeOfInt8:Int = 1
    static let sizeOfInt16:Int = 2
    static let sizeOfInt24:Int = 3
    static let sizeOfInt32:Int = 4
    static let sizeOfFloat:Int = 4
    static let sizeOfDouble:Int = 8

    private(set) var bytes:[UInt8] = []

    public var length:Int {
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

    public var position:Int = 0

    public var bytesAvailable:Int {
        return bytes.count - position
    }

    public subscript(i: Int) -> UInt8 {
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

    public func readUInt8() throws -> UInt8 {
        guard ByteArray.sizeOfInt8 <= bytesAvailable else {
            throw ByteArrayError.EOF
        }
        return bytes[position++]
    }

    public func writeUInt8(value:UInt8) -> ByteArray {
        return writeBytes([value])
    }

    public func readInt8() throws -> Int8 {
        guard ByteArray.sizeOfInt8 <= bytesAvailable else {
            throw ByteArrayError.EOF
        }
        return Int8(bitPattern: UInt8(bytes[position++]))
    }

    public func writeInt8(value:Int8) -> ByteArray {
        return writeBytes([UInt8(bitPattern: value)])
    }

    public func readUInt16() throws -> UInt16 {
        guard ByteArray.sizeOfInt16 <= bytesAvailable else {
            throw ByteArrayError.EOF
        }
        position += ByteArray.sizeOfInt16
        return UInt16(bytes: Array(bytes[position - ByteArray.sizeOfInt16..<position])).bigEndian
    }

    public func writeUInt16(value:UInt16) -> ByteArray {
        return writeBytes(value.bigEndian.bytes)
    }

    public func readInt16() throws -> Int16 {
        guard ByteArray.sizeOfInt16 <= bytesAvailable else {
            throw ByteArrayError.EOF
        }
        position += ByteArray.sizeOfInt16
        return Int16(bytes: Array(bytes[position - ByteArray.sizeOfInt16..<position])).bigEndian
    }

    public func writeInt16(value:Int16) -> ByteArray {
        return writeBytes(value.bigEndian.bytes)
    }

    public func readUInt24() throws -> UInt32 {
        guard ByteArray.sizeOfInt24 <= bytesAvailable else {
            throw ByteArrayError.EOF
        }
        return (UInt32(bytes[position++]) << 16) | (UInt32(bytes[position++]) << 8) | UInt32(bytes[position++])
    }

    public func writeUInt24(value:UInt32) -> ByteArray {
        return writeBytes(Array(value.bigEndian.bytes[1...ByteArray.sizeOfInt24]))
    }

    public func readUInt32() throws -> UInt32 {
        guard ByteArray.sizeOfInt32 <= bytesAvailable else {
            throw ByteArrayError.EOF
        }
        position += ByteArray.sizeOfInt32
        return UInt32(bytes: Array(bytes[position - ByteArray.sizeOfInt32..<position])).bigEndian
    }

    public func writeUInt32(value:UInt32) -> ByteArray {
        return writeBytes(value.bigEndian.bytes)
    }

    public func readInt32() throws -> Int32 {
        guard ByteArray.sizeOfInt32 <= bytesAvailable else {
            throw ByteArrayError.EOF
        }
        position += ByteArray.sizeOfInt32
        return Int32(bytes: Array(bytes[position - ByteArray.sizeOfInt32..<position])).bigEndian
    }

    public func writeInt32(value:Int32) -> ByteArray {
        return writeBytes(value.bigEndian.bytes)
    }

    public func readDouble() throws -> Double {
        guard ByteArray.sizeOfDouble <= bytesAvailable else {
            throw ByteArrayError.EOF
        }
        position += ByteArray.sizeOfDouble
        return Double(bytes: Array(bytes[position - ByteArray.sizeOfDouble..<position].reverse()))
    }

    public func writeDouble(value:Double) -> ByteArray {
        return writeBytes(value.bytes.reverse())
    }

    public func readFloat() throws -> Float {
        guard ByteArray.sizeOfFloat <= bytesAvailable else {
            throw ByteArrayError.EOF
        }
        position += ByteArray.sizeOfFloat
        return Float(bytes: Array(bytes[position - ByteArray.sizeOfFloat..<position].reverse()))
    }

    public func writeFloat(value:Float) -> ByteArray {
        return writeBytes(value.bytes.reverse())
    }

    public func readUTF8() throws -> String {
        return try readUTF8Bytes(Int(try readUInt16()))
    }

    public func writeUTF8(value:String) throws -> ByteArray {
        let utf8:[UInt8] = [UInt8](value.utf8)
        return writeUInt16(UInt16(utf8.count)).writeBytes(utf8)
    }

    public func readUTF8Bytes(length:Int) throws -> String {
        guard length <= bytesAvailable else {
            throw ByteArrayError.EOF
        }
        position += length
        guard let result:String = String(bytes: Array(bytes[position - length..<position]), encoding: NSUTF8StringEncoding) else {
            throw ByteArrayError.Parse
        }
        return result
    }

    public func writeUTF8Bytes(value:String) -> ByteArray {
        return writeBytes([UInt8](value.utf8))
    }

    public func readBytes(length:Int) throws -> [UInt8] {
        guard length <= bytesAvailable else {
            throw ByteArrayError.EOF
        }
        position += length
        return Array(bytes[position - length..<position])
    }

    public func writeBytes(value:[UInt8]) -> ByteArray {

        if (position == bytes.count) {
            bytes += value
            position = bytes.count
            return self
        }

        let length:Int = min(bytes.count, value.count)
        bytes[position..<position + length] = value[0..<length]
        if (length == bytes.count) {
            bytes += value[length..<value.count]
        }
        position += value.count

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
    public var description:String {
        var description:String = "ByteArray{"
        description += "position:\(position),"
        description += "bytesAvailable:\(bytesAvailable),"
        description += "bytes:\(bytes)}"
        return description
    }
}
