import Foundation

// MARK: ByteArrayError
public enum ByteArrayError: ErrorType {
    case EOF
    case Parse
}

// MARK: - ByteArrayConvertible
protocol ByteArrayConvertible {

    var bytes:[UInt8] { get }
    var length:Int { get set }
    var position:Int { get set }
    var bytesAvailable:Int { get }
    subscript(i: Int) -> UInt8 { get set }

    func readUInt8() throws -> UInt8
    func writeUInt8(value:UInt8) -> Self

    func readInt8() throws -> Int8
    func writeInt8(value:Int8) -> Self

    func readUInt16() throws -> UInt16
    func writeUInt16(value:UInt16) -> Self

    func readInt16() throws -> Int16
    func writeInt16(value:Int16) -> Self

    func readUInt24() throws -> UInt32
    func writeUInt24(value:UInt32) -> Self

    func readUInt32() throws -> UInt32
    func writeUInt32(value:UInt32) -> Self

    func readInt32() throws -> Int32
    func writeInt32(value:Int32) -> Self

    func readDouble() throws -> Double
    func writeDouble(value:Double) -> Self

    func readFloat() throws -> Float
    func writeFloat(value:Float) -> Self

    func readUTF8() throws -> String
    func writeUTF8(value:String) throws -> Self

    func readUTF8Bytes(length:Int) throws -> String
    func writeUTF8Bytes(value:String) -> Self

    func readBytes(length:Int) throws -> [UInt8]
    func writeBytes(value:[UInt8]) -> Self

    func clear() -> Self
}

// MARK: -
public class ByteArray: ByteArrayConvertible {
    static let sizeOfInt8:Int = 1
    static let sizeOfInt16:Int = 2
    static let sizeOfInt24:Int = 3
    static let sizeOfInt32:Int = 4
    static let sizeOfFloat:Int = 4
    static let sizeOfDouble:Int = 8

    init() {
    }

    init(bytes:[UInt8]) {
        self.bytes = bytes
    }

    init(data:NSData) {
        bytes = [UInt8](count: data.length, repeatedValue: 0x00)
        data.getBytes(&bytes, length: data.length)
    }

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

    public func readUInt8() throws -> UInt8 {
        guard ByteArray.sizeOfInt8 <= bytesAvailable else {
            throw ByteArrayError.EOF
        }
        defer {
            position += 1
        }
        return bytes[position]
    }

    public func writeUInt8(value:UInt8) -> Self {
        return writeBytes([value])
    }

    public func readInt8() throws -> Int8 {
        guard ByteArray.sizeOfInt8 <= bytesAvailable else {
            throw ByteArrayError.EOF
        }
        defer {
            position += 1
        }
        return Int8(bitPattern: UInt8(bytes[position]))
    }

    public func writeInt8(value:Int8) -> Self {
        return writeBytes([UInt8(bitPattern: value)])
    }

    public func readUInt16() throws -> UInt16 {
        guard ByteArray.sizeOfInt16 <= bytesAvailable else {
            throw ByteArrayError.EOF
        }
        position += ByteArray.sizeOfInt16
        return UInt16(bytes: Array(bytes[position - ByteArray.sizeOfInt16..<position])).bigEndian
    }

    public func writeUInt16(value:UInt16) -> Self {
        return writeBytes(value.bigEndian.bytes)
    }

    public func readInt16() throws -> Int16 {
        guard ByteArray.sizeOfInt16 <= bytesAvailable else {
            throw ByteArrayError.EOF
        }
        position += ByteArray.sizeOfInt16
        return Int16(bytes: Array(bytes[position - ByteArray.sizeOfInt16..<position])).bigEndian
    }

    public func writeInt16(value:Int16) -> Self {
        return writeBytes(value.bigEndian.bytes)
    }

    public func readUInt24() throws -> UInt32 {
        guard ByteArray.sizeOfInt24 <= bytesAvailable else {
            throw ByteArrayError.EOF
        }
        position += ByteArray.sizeOfInt24
        return UInt32(bytes: [0] + Array(bytes[position - ByteArray.sizeOfInt24..<position])).bigEndian
    }

    public func writeUInt24(value:UInt32) -> Self {
        return writeBytes(Array(value.bigEndian.bytes[1...ByteArray.sizeOfInt24]))
    }

    public func readUInt32() throws -> UInt32 {
        guard ByteArray.sizeOfInt32 <= bytesAvailable else {
            throw ByteArrayError.EOF
        }
        position += ByteArray.sizeOfInt32
        return UInt32(bytes: Array(bytes[position - ByteArray.sizeOfInt32..<position])).bigEndian
    }

    public func writeUInt32(value:UInt32) -> Self {
        return writeBytes(value.bigEndian.bytes)
    }

    public func readInt32() throws -> Int32 {
        guard ByteArray.sizeOfInt32 <= bytesAvailable else {
            throw ByteArrayError.EOF
        }
        position += ByteArray.sizeOfInt32
        return Int32(bytes: Array(bytes[position - ByteArray.sizeOfInt32..<position])).bigEndian
    }

    public func writeInt32(value:Int32) -> Self {
        return writeBytes(value.bigEndian.bytes)
    }

    public func readDouble() throws -> Double {
        guard ByteArray.sizeOfDouble <= bytesAvailable else {
            throw ByteArrayError.EOF
        }
        position += ByteArray.sizeOfDouble
        return Double(bytes: Array(bytes[position - ByteArray.sizeOfDouble..<position].reverse()))
    }

    public func writeDouble(value:Double) -> Self {
        return writeBytes(value.bytes.reverse())
    }

    public func readFloat() throws -> Float {
        guard ByteArray.sizeOfFloat <= bytesAvailable else {
            throw ByteArrayError.EOF
        }
        position += ByteArray.sizeOfFloat
        return Float(bytes: Array(bytes[position - ByteArray.sizeOfFloat..<position].reverse()))
    }

    public func writeFloat(value:Float) -> Self {
        return writeBytes(value.bytes.reverse())
    }

    public func readUTF8() throws -> String {
        return try readUTF8Bytes(Int(try readUInt16()))
    }

    public func writeUTF8(value:String) throws -> Self {
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

    public func writeUTF8Bytes(value:String) -> Self {
        return writeBytes([UInt8](value.utf8))
    }

    public func readBytes(length:Int) throws -> [UInt8] {
        guard length <= bytesAvailable else {
            throw ByteArrayError.EOF
        }
        position += length
        return Array(bytes[position - length..<position])
    }

    public func writeBytes(value:[UInt8]) -> Self {
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

    public func clear() -> Self {
        position = 0
        bytes.removeAll(keepCapacity: false)
        return self
    }
}

// MARK: CustomStringConvertible
extension ByteArray: CustomStringConvertible {
    public var description:String {
        return Mirror(reflecting: self).description
    }
}

