import Foundation

protocol ByteArrayConvertible {
    var data: Data { get }
    var length: Int { get set }
    var position: Int { get set }
    var bytesAvailable: Int { get }

    subscript(i: Int) -> UInt8 { get set }

    @discardableResult
    func writeUInt8(_ value: UInt8) -> Self
    func readUInt8() throws -> UInt8

    @discardableResult
    func writeInt8(_ value: Int8) -> Self
    func readInt8() throws -> Int8

    @discardableResult
    func writeUInt16(_ value: UInt16) -> Self
    func readUInt16() throws -> UInt16

    @discardableResult
    func writeInt16(_ value: Int16) -> Self
    func readInt16() throws -> Int16

    @discardableResult
    func writeUInt24(_ value: UInt32) -> Self
    func readUInt24() throws -> UInt32

    @discardableResult
    func writeUInt32(_ value: UInt32) -> Self
    func readUInt32() throws -> UInt32

    @discardableResult
    func writeInt32(_ value: Int32) -> Self
    func readInt32() throws -> Int32

    @discardableResult
    func writeUInt64(_ value: UInt64) -> Self
    func readUInt64() throws -> UInt64

    @discardableResult
    func writeInt64(_ value: Int64) -> Self
    func readInt64() throws -> Int64

    @discardableResult
    func writeDouble(_ value: Double) -> Self
    func readDouble() throws -> Double

    @discardableResult
    func writeFloat(_ value: Float) -> Self
    func readFloat() throws -> Float

    @discardableResult
    func writeUTF8(_ value: String) throws -> Self
    func readUTF8() throws -> String

    @discardableResult
    func writeUTF8Bytes(_ value: String) -> Self
    func readUTF8Bytes(_ length: Int) throws -> String

    @discardableResult
    func writeBytes(_ value: Data) -> Self
    func readBytes(_ length: Int) throws -> Data

    @discardableResult
    func clear() -> Self
}

// MARK: -
/**
 * The ByteArray class provides methods and properties the reading or writing with binary data.
 */
class ByteArray: ByteArrayConvertible {
    static let fillZero: [UInt8] = [0x00]

    static let sizeOfInt8: Int = 1
    static let sizeOfInt16: Int = 2
    static let sizeOfInt24: Int = 3
    static let sizeOfInt32: Int = 4
    static let sizeOfFloat: Int = 4
    static let sizeOfInt64: Int = 8
    static let sizeOfDouble: Int = 8

    /**
     * The ByteArray error domain codes.
     */
    enum Error: Swift.Error {
        /// Error cause end of data.
        case eof
        /// Failed to parse
        case parse
    }

    /// Creates an empty ByteArray.
    init() {
    }

    /// Creates a ByteArray with data.
    init(data: Data) {
        self.data = data
    }

    private(set) var data = Data()

    /// Specifies the length of buffer.
    var length: Int {
        get {
            data.count
        }
        set {
            switch true {
            case (data.count < newValue):
                data.append(Data(count: newValue - data.count))
            case (newValue < data.count):
                data = data.subdata(in: 0..<newValue)
            default:
                break
            }
        }
    }

    /// Specifies the position of buffer.
    var position: Int = 0

    /// The bytesAvalibale or not.
    var bytesAvailable: Int {
        data.count - position
    }

    subscript(i: Int) -> UInt8 {
        get {
            data[i]
        }
        set {
            data[i] = newValue
        }
    }

    /// Reading an UInt8 value.
    func readUInt8() throws -> UInt8 {
        guard ByteArray.sizeOfInt8 <= bytesAvailable else {
            throw ByteArray.Error.eof
        }
        defer {
            position += 1
        }
        return data[position]
    }

    /// Writing an UInt8 value.
    @discardableResult
    func writeUInt8(_ value: UInt8) -> Self {
        writeBytes(value.data)
    }

    /// Readning an Int8 value.
    func readInt8() throws -> Int8 {
        guard ByteArray.sizeOfInt8 <= bytesAvailable else {
            throw ByteArray.Error.eof
        }
        defer {
            position += 1
        }
        return Int8(bitPattern: UInt8(data[position]))
    }

    /// Writing an Int8 value.
    @discardableResult
    func writeInt8(_ value: Int8) -> Self {
        writeBytes(UInt8(bitPattern: value).data)
    }

    /// Readning an UInt16 value.
    func readUInt16() throws -> UInt16 {
        guard ByteArray.sizeOfInt16 <= bytesAvailable else {
            throw ByteArray.Error.eof
        }
        position += ByteArray.sizeOfInt16
        return UInt16(data: data[position - ByteArray.sizeOfInt16..<position]).bigEndian
    }

    /// Writing an UInt16 value.
    @discardableResult
    func writeUInt16(_ value: UInt16) -> Self {
        writeBytes(value.bigEndian.data)
    }

    /// Reading an Int16 value.
    func readInt16() throws -> Int16 {
        guard ByteArray.sizeOfInt16 <= bytesAvailable else {
            throw ByteArray.Error.eof
        }
        position += ByteArray.sizeOfInt16
        return Int16(data: data[position - ByteArray.sizeOfInt16..<position]).bigEndian
    }

    /// Reading an Int16 value.
    @discardableResult
    func writeInt16(_ value: Int16) -> Self {
        writeBytes(value.bigEndian.data)
    }

    /// Reading an UInt24 value.
    func readUInt24() throws -> UInt32 {
        guard ByteArray.sizeOfInt24 <= bytesAvailable else {
            throw ByteArray.Error.eof
        }
        position += ByteArray.sizeOfInt24
        return UInt32(data: ByteArray.fillZero + data[position - ByteArray.sizeOfInt24..<position]).bigEndian
    }

    /// Writing an UInt24 value.
    @discardableResult
    func writeUInt24(_ value: UInt32) -> Self {
        writeBytes(value.bigEndian.data.subdata(in: 1..<ByteArray.sizeOfInt24 + 1))
    }

    /// Reading an UInt32 value.
    func readUInt32() throws -> UInt32 {
        guard ByteArray.sizeOfInt32 <= bytesAvailable else {
            throw ByteArray.Error.eof
        }
        position += ByteArray.sizeOfInt32
        return UInt32(data: data[position - ByteArray.sizeOfInt32..<position]).bigEndian
    }

    /// Writing an UInt32 value.
    @discardableResult
    func writeUInt32(_ value: UInt32) -> Self {
        writeBytes(value.bigEndian.data)
    }

    /// Reading an Int32 value.
    func readInt32() throws -> Int32 {
        guard ByteArray.sizeOfInt32 <= bytesAvailable else {
            throw ByteArray.Error.eof
        }
        position += ByteArray.sizeOfInt32
        return Int32(data: data[position - ByteArray.sizeOfInt32..<position]).bigEndian
    }

    /// Writing an Int32 value.
    @discardableResult
    func writeInt32(_ value: Int32) -> Self {
        writeBytes(value.bigEndian.data)
    }

    /// Writing an UInt64 value.
    @discardableResult
    func writeUInt64(_ value: UInt64) -> Self {
        writeBytes(value.bigEndian.data)
    }

    /// Reading an UInt64 value.
    func readUInt64() throws -> UInt64 {
        guard ByteArray.sizeOfInt64 <= bytesAvailable else {
            throw ByteArray.Error.eof
        }
        position += ByteArray.sizeOfInt64
        return UInt64(data: data[position - ByteArray.sizeOfInt64..<position]).bigEndian
    }

    /// Writing an Int64 value.
    func writeInt64(_ value: Int64) -> Self {
        writeBytes(value.bigEndian.data)
    }

    /// Reading an Int64 value.
    func readInt64() throws -> Int64 {
        guard ByteArray.sizeOfInt64 <= bytesAvailable else {
            throw ByteArray.Error.eof
        }
        position += ByteArray.sizeOfInt64
        return Int64(data: data[position - ByteArray.sizeOfInt64..<position]).bigEndian
    }

    /// Reading a Double value.
    func readDouble() throws -> Double {
        guard ByteArray.sizeOfDouble <= bytesAvailable else {
            throw ByteArray.Error.eof
        }
        position += ByteArray.sizeOfDouble
        return Double(data: Data(data.subdata(in: position - ByteArray.sizeOfDouble..<position).reversed()))
    }

    /// Writing a Double value.
    @discardableResult
    func writeDouble(_ value: Double) -> Self {
        writeBytes(Data(value.data.reversed()))
    }

    /// Reading a Float value.
    func readFloat() throws -> Float {
        guard ByteArray.sizeOfFloat <= bytesAvailable else {
            throw ByteArray.Error.eof
        }
        position += ByteArray.sizeOfFloat
        return Float(data: Data(data.subdata(in: position - ByteArray.sizeOfFloat..<position).reversed()))
    }

    /// Writeing a Float value.
    @discardableResult
    func writeFloat(_ value: Float) -> Self {
        writeBytes(Data(value.data.reversed()))
    }

    /// Reading a string as UTF8 value.
    func readUTF8() throws -> String {
        try readUTF8Bytes(Int(try readUInt16()))
    }

    /// Writing a string as UTF8 value.
    @discardableResult
    func writeUTF8(_ value: String) throws -> Self {
        let utf8 = Data(value.utf8)
        return writeUInt16(UInt16(utf8.count)).writeBytes(utf8)
    }

    /// Clear the buffer.
    @discardableResult
    func clear() -> Self {
        position = 0
        data.removeAll()
        return self
    }

    func readUTF8Bytes(_ length: Int) throws -> String {
        guard length <= bytesAvailable else {
            throw ByteArray.Error.eof
        }
        position += length

        guard let result = String(data: data.subdata(in: position - length..<position), encoding: .utf8) else {
            throw ByteArray.Error.parse
        }
        return result
    }

    @discardableResult
    func writeUTF8Bytes(_ value: String) -> Self {
        writeBytes(Data(value.utf8))
    }

    func readBytes(_ length: Int) throws -> Data {
        guard length <= bytesAvailable else {
            throw ByteArray.Error.eof
        }
        position += length
        return data.subdata(in: position - length..<position)
    }

    @discardableResult
    func writeBytes(_ value: Data) -> Self {
        if position == data.count {
            data.append(value)
            position = data.count
            return self
        }
        let length: Int = min(data.count, value.count)
        data[position..<position + length] = value[0..<length]
        if length == data.count {
            data.append(value[length..<value.count])
        }
        position += value.count
        return self
    }

    func sequence(_ length: Int, lambda: ((ByteArray) -> Void)) {
        let r: Int = (data.count - position) % length
        for index in stride(from: data.startIndex.advanced(by: position), to: data.endIndex.advanced(by: -r), by: length) {
            lambda(ByteArray(data: data.subdata(in: index..<index.advanced(by: length))))
        }
        if 0 < r {
            lambda(ByteArray(data: data.advanced(by: data.endIndex - r)))
        }
    }

    func toUInt32() -> [UInt32] {
        let size: Int = MemoryLayout<UInt32>.size
        if (data.endIndex - position) % size != 0 {
            return []
        }
        var result: [UInt32] = []
        for index in stride(from: data.startIndex.advanced(by: position), to: data.endIndex, by: size) {
            result.append(UInt32(data: data[index..<index.advanced(by: size)]))
        }
        return result
    }
}

extension ByteArray: CustomDebugStringConvertible {
    // MARK: CustomDebugStringConvertible
    public var debugDescription: String {
        Mirror(reflecting: self).debugDescription
    }
}
