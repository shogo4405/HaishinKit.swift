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
open class ByteArray: ByteArrayConvertible {
    static let fillZero: [UInt8] = [0x00]

    static let sizeOfInt8: Int = 1
    static let sizeOfInt16: Int = 2
    static let sizeOfInt24: Int = 3
    static let sizeOfInt32: Int = 4
    static let sizeOfFloat: Int = 4
    static let sizeOfDouble: Int = 8

    public enum Error: Swift.Error {
        case eof
        case parse
    }

    init() {
    }

    init(data: Data) {
        self.data = data
    }

    private(set) var data = Data()

    open var length: Int {
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

    open var position: Int = 0

    open var bytesAvailable: Int {
        data.count - position
    }

    open subscript(i: Int) -> UInt8 {
        get {
            data[i]
        }
        set {
            data[i] = newValue
        }
    }

    open func readUInt8() throws -> UInt8 {
        guard ByteArray.sizeOfInt8 <= bytesAvailable else {
            throw ByteArray.Error.eof
        }
        defer {
            position += 1
        }
        return data[position]
    }

    @discardableResult
    open func writeUInt8(_ value: UInt8) -> Self {
        writeBytes(value.data)
    }

    open func readInt8() throws -> Int8 {
        guard ByteArray.sizeOfInt8 <= bytesAvailable else {
            throw ByteArray.Error.eof
        }
        defer {
            position += 1
        }
        return Int8(bitPattern: UInt8(data[position]))
    }

    @discardableResult
    open func writeInt8(_ value: Int8) -> Self {
        writeBytes(UInt8(bitPattern: value).data)
    }

    open func readUInt16() throws -> UInt16 {
        guard ByteArray.sizeOfInt16 <= bytesAvailable else {
            throw ByteArray.Error.eof
        }
        position += ByteArray.sizeOfInt16
        return UInt16(data: data[position - ByteArray.sizeOfInt16..<position]).bigEndian
    }

    @discardableResult
    open func writeUInt16(_ value: UInt16) -> Self {
        writeBytes(value.bigEndian.data)
    }

    open func readInt16() throws -> Int16 {
        guard ByteArray.sizeOfInt16 <= bytesAvailable else {
            throw ByteArray.Error.eof
        }
        position += ByteArray.sizeOfInt16
        return Int16(data: data[position - ByteArray.sizeOfInt16..<position]).bigEndian
    }

    @discardableResult
    open func writeInt16(_ value: Int16) -> Self {
        writeBytes(value.bigEndian.data)
    }

    open func readUInt24() throws -> UInt32 {
        guard ByteArray.sizeOfInt24 <= bytesAvailable else {
            throw ByteArray.Error.eof
        }
        position += ByteArray.sizeOfInt24
        return UInt32(data: ByteArray.fillZero + data[position - ByteArray.sizeOfInt24..<position]).bigEndian
    }

    @discardableResult
    open func writeUInt24(_ value: UInt32) -> Self {
        writeBytes(value.bigEndian.data.subdata(in: 1..<ByteArray.sizeOfInt24 + 1))
    }

    open func readUInt32() throws -> UInt32 {
        guard ByteArray.sizeOfInt32 <= bytesAvailable else {
            throw ByteArray.Error.eof
        }
        position += ByteArray.sizeOfInt32
        return UInt32(data: data[position - ByteArray.sizeOfInt32..<position]).bigEndian
    }

    @discardableResult
    open func writeUInt32(_ value: UInt32) -> Self {
        writeBytes(value.bigEndian.data)
    }

    open func readInt32() throws -> Int32 {
        guard ByteArray.sizeOfInt32 <= bytesAvailable else {
            throw ByteArray.Error.eof
        }
        position += ByteArray.sizeOfInt32
        return Int32(data: data[position - ByteArray.sizeOfInt32..<position]).bigEndian
    }

    @discardableResult
    open func writeInt32(_ value: Int32) -> Self {
        writeBytes(value.bigEndian.data)
    }

    open func readDouble() throws -> Double {
        guard ByteArray.sizeOfDouble <= bytesAvailable else {
            throw ByteArray.Error.eof
        }
        position += ByteArray.sizeOfDouble
        return Double(data: Data(data.subdata(in: position - ByteArray.sizeOfDouble..<position).reversed()))
    }

    @discardableResult
    open func writeDouble(_ value: Double) -> Self {
        writeBytes(Data(value.data.reversed()))
    }

    open func readFloat() throws -> Float {
        guard ByteArray.sizeOfFloat <= bytesAvailable else {
            throw ByteArray.Error.eof
        }
        position += ByteArray.sizeOfFloat
        return Float(data: Data(data.subdata(in: position - ByteArray.sizeOfFloat..<position).reversed()))
    }

    @discardableResult
    open func writeFloat(_ value: Float) -> Self {
        writeBytes(Data(value.data.reversed()))
    }

    open func readUTF8() throws -> String {
        try readUTF8Bytes(Int(try readUInt16()))
    }

    @discardableResult
    open func writeUTF8(_ value: String) throws -> Self {
        let utf8 = Data(value.utf8)
        return writeUInt16(UInt16(utf8.count)).writeBytes(utf8)
    }

    open func readUTF8Bytes(_ length: Int) throws -> String {
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
    open func writeUTF8Bytes(_ value: String) -> Self {
        writeBytes(Data(value.utf8))
    }

    open func readBytes(_ length: Int) throws -> Data {
        guard length <= bytesAvailable else {
            throw ByteArray.Error.eof
        }
        position += length
        return data.subdata(in: position - length..<position)
    }

    @discardableResult
    open func writeBytes(_ value: Data) -> Self {
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

    @discardableResult
    open func clear() -> Self {
        position = 0
        data.removeAll()
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
