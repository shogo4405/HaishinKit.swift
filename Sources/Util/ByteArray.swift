import Foundation

protocol ByteArrayConvertible {

    var bytes:[UInt8] { get }
    var length:Int { get set }
    var position:Int { get set }
    var bytesAvailable:Int { get }
    subscript(i: Int) -> UInt8 { get set }

    @discardableResult
    func writeUInt8(_ value:UInt8) -> Self
    func readUInt8() throws -> UInt8

    @discardableResult
    func writeInt8(_ value:Int8) -> Self
    func readInt8() throws -> Int8

    @discardableResult
    func writeUInt16(_ value:UInt16) -> Self
    func readUInt16() throws -> UInt16

    @discardableResult
    func writeInt16(_ value:Int16) -> Self
    func readInt16() throws -> Int16

    @discardableResult
    func writeUInt24(_ value:UInt32) -> Self
    func readUInt24() throws -> UInt32

    @discardableResult
    func writeUInt32(_ value:UInt32) -> Self
    func readUInt32() throws -> UInt32

    @discardableResult
    func writeInt32(_ value:Int32) -> Self
    func readInt32() throws -> Int32

    @discardableResult
    func writeDouble(_ value:Double) -> Self
    func readDouble() throws -> Double

    @discardableResult
    func writeFloat(_ value:Float) -> Self
    func readFloat() throws -> Float

    @discardableResult
    func writeUTF8(_ value:String) throws -> Self
    func readUTF8() throws -> String

    @discardableResult
    func writeUTF8Bytes(_ value:String) -> Self
    func readUTF8Bytes(_ length:Int) throws -> String

    @discardableResult
    func writeBytes(_ value:[UInt8]) -> Self
    func readBytes(_ length:Int) throws -> [UInt8]

    @discardableResult
    func clear() -> Self
}

// MARK: -
open class ByteArray: ByteArrayConvertible {
    static let sizeOfInt8:Int = 1
    static let sizeOfInt16:Int = 2
    static let sizeOfInt24:Int = 3
    static let sizeOfInt32:Int = 4
    static let sizeOfFloat:Int = 4
    static let sizeOfDouble:Int = 8

    public enum Error: Swift.Error {
        case eof
        case parse
    }

    init() {
    }

    init(bytes:[UInt8]) {
        self.bytes = bytes
    }

    init(data:Data) {
        bytes = [UInt8](repeating: 0x00, count: data.count)
        (data as NSData).getBytes(&bytes, length: data.count)
    }

    fileprivate(set) var bytes:[UInt8] = []

    open var length:Int {
        get {
            return bytes.count
        }
        set {
            switch true {
            case (bytes.count < newValue):
                bytes += [UInt8](repeating: 0, count: newValue - bytes.count)
            case (newValue < bytes.count):
                bytes = Array(bytes[0..<newValue])
            default:
                break
            }
        }
    }

    open var position:Int = 0

    open var bytesAvailable:Int {
        return bytes.count - position
    }

    open subscript(i: Int) -> UInt8 {
        get {
            return bytes[i]
        }
        set {
            bytes[i] = newValue
        }
    }

    open func readUInt8() throws -> UInt8 {
        guard ByteArray.sizeOfInt8 <= bytesAvailable else {
            throw ByteArray.Error.eof
        }
        defer {
            position += 1
        }
        return bytes[position]
    }

    @discardableResult
    open func writeUInt8(_ value:UInt8) -> Self {
        return writeBytes([value])
    }

    open func readInt8() throws -> Int8 {
        guard ByteArray.sizeOfInt8 <= bytesAvailable else {
            throw ByteArray.Error.eof
        }
        defer {
            position += 1
        }
        return Int8(bitPattern: UInt8(bytes[position]))
    }

    @discardableResult
    open func writeInt8(_ value:Int8) -> Self {
        return writeBytes([UInt8(bitPattern: value)])
    }

    open func readUInt16() throws -> UInt16 {
        guard ByteArray.sizeOfInt16 <= bytesAvailable else {
            throw ByteArray.Error.eof
        }
        position += ByteArray.sizeOfInt16
        return UInt16(bytes: Array(bytes[position - ByteArray.sizeOfInt16..<position])).bigEndian
    }

    @discardableResult
    open func writeUInt16(_ value:UInt16) -> Self {
        return writeBytes(value.bigEndian.bytes)
    }

    open func readInt16() throws -> Int16 {
        guard ByteArray.sizeOfInt16 <= bytesAvailable else {
            throw ByteArray.Error.eof
        }
        position += ByteArray.sizeOfInt16
        return Int16(bytes: Array(bytes[position - ByteArray.sizeOfInt16..<position])).bigEndian
    }

    @discardableResult
    open func writeInt16(_ value:Int16) -> Self {
        return writeBytes(value.bigEndian.bytes)
    }

    open func readUInt24() throws -> UInt32 {
        guard ByteArray.sizeOfInt24 <= bytesAvailable else {
            throw ByteArray.Error.eof
        }
        position += ByteArray.sizeOfInt24
        return UInt32(bytes: [0] + Array(bytes[position - ByteArray.sizeOfInt24..<position])).bigEndian
    }

    @discardableResult
    open func writeUInt24(_ value:UInt32) -> Self {
        return writeBytes(Array(value.bigEndian.bytes[1...ByteArray.sizeOfInt24]))
    }

    open func readUInt32() throws -> UInt32 {
        guard ByteArray.sizeOfInt32 <= bytesAvailable else {
            throw ByteArray.Error.eof
        }
        position += ByteArray.sizeOfInt32
        return UInt32(bytes: Array(bytes[position - ByteArray.sizeOfInt32..<position])).bigEndian
    }

    @discardableResult
    open func writeUInt32(_ value:UInt32) -> Self {
        return writeBytes(value.bigEndian.bytes)
    }

    open func readInt32() throws -> Int32 {
        guard ByteArray.sizeOfInt32 <= bytesAvailable else {
            throw ByteArray.Error.eof
        }
        position += ByteArray.sizeOfInt32
        return Int32(bytes: Array(bytes[position - ByteArray.sizeOfInt32..<position])).bigEndian
    }

    @discardableResult
    open func writeInt32(_ value:Int32) -> Self {
        return writeBytes(value.bigEndian.bytes)
    }

    open func readDouble() throws -> Double {
        guard ByteArray.sizeOfDouble <= bytesAvailable else {
            throw ByteArray.Error.eof
        }
        position += ByteArray.sizeOfDouble
        return Double(bytes: Array(bytes[position - ByteArray.sizeOfDouble..<position].reversed()))
    }

    @discardableResult
    open func writeDouble(_ value:Double) -> Self {
        return writeBytes(value.bytes.reversed())
    }

    open func readFloat() throws -> Float {
        guard ByteArray.sizeOfFloat <= bytesAvailable else {
            throw ByteArray.Error.eof
        }
        position += ByteArray.sizeOfFloat
        return Float(bytes: Array(bytes[position - ByteArray.sizeOfFloat..<position].reversed()))
    }

    @discardableResult
    open func writeFloat(_ value:Float) -> Self {
        return writeBytes(value.bytes.reversed())
    }

    open func readUTF8() throws -> String {
        return try readUTF8Bytes(Int(try readUInt16()))
    }

    @discardableResult
    open func writeUTF8(_ value:String) throws -> Self {
        let utf8:[UInt8] = [UInt8](value.utf8)
        return writeUInt16(UInt16(utf8.count)).writeBytes(utf8)
    }

    open func readUTF8Bytes(_ length:Int) throws -> String {
        guard length <= bytesAvailable else {
            throw ByteArray.Error.eof
        }
        position += length
        guard let result:String = String(bytes: Array(bytes[position - length..<position]), encoding: String.Encoding.utf8) else {
            throw ByteArray.Error.parse
        }
        return result
    }

    @discardableResult
    open func writeUTF8Bytes(_ value:String) -> Self {
        return writeBytes([UInt8](value.utf8))
    }

    open func readBytes(_ length:Int) throws -> [UInt8] {
        guard length <= bytesAvailable else {
            throw ByteArray.Error.eof
        }
        position += length
        return Array(bytes[position - length..<position])
    }

    @discardableResult
    open func writeBytes(_ value:[UInt8]) -> Self {
        if (position == bytes.count) {
            bytes.append(contentsOf: value)
            position = bytes.count
            return self
        }
        let length:Int = min(bytes.count, value.count)
        bytes[position..<position + length] = value[0..<length]
        if (length == bytes.count) {
            bytes.append(contentsOf: value[length..<value.count])
        }
        position += value.count
        return self
    }

    @discardableResult
    open func clear() -> Self {
        position = 0
        bytes.removeAll()
        return self
    }

    func sequence(_ length:Int, lambda:((ByteArray) -> Void)) {
        let r:Int = (bytes.count - position) % length
        for index in stride(from: bytes.startIndex.advanced(by: position), to: bytes.endIndex.advanced(by: -r), by: length) {
            lambda(ByteArray(bytes: Array(bytes[index..<index.advanced(by: length)])))
        }
        if (0 < r) {
            lambda(ByteArray(bytes: Array(bytes[bytes.indices.suffix(from: bytes.endIndex - r)])))
        }
    }

    func toUInt32() -> [UInt32] {
        let size:Int = MemoryLayout<UInt32>.size
        if ((bytes.endIndex - position) % size != 0) {
            return []
        }
        var result:[UInt32] = []
        for index in stride(from: bytes.startIndex.advanced(by: position), to: bytes.endIndex, by: size) {
            result.append(UInt32(bytes: Array(bytes[index..<index.advanced(by: size)])))
        }
        return result
    }
}

extension ByteArray: CustomStringConvertible {
    // MARK: CustomStringConvertible
    public var description:String {
        return Mirror(reflecting: self).description
    }
}
