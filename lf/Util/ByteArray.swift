import Foundation

final class ByteArray: CustomStringConvertible {
    private var _bytes:[UInt8] = []
    var bytes:[UInt8] {
        return _bytes
    }

    var position:Int = 0

    var length:Int {
        return _bytes.count
    }

    var description:String {
        return _bytes.description
    }

    init() {
    }

    init (bytes:[UInt8]) {
        _bytes = bytes
    }

    init (data:NSData) {
        _bytes = [UInt8](count: data.length, repeatedValue: 0x00)
        data.getBytes(&_bytes, length: data.length)
    }

    func readUInt8() -> UInt8 {
        return _bytes[position++]
    }

    func writeUInt8(value:UInt8) -> ByteArray {
        _bytes.append(value)
        return self
    }

    func readUInt8(length:Int) -> [UInt8] {
        position += length
        return Array(_bytes[position - length..<position])
    }

    func writeUInt8(value:[UInt8]) -> ByteArray {
        _bytes += value
        return self
    }

    func readUInt16() -> UInt16 {
        position += 2
        return UInt16(bytes: Array(_bytes[position - 2..<position])).bigEndian
    }

    func readUInt24() -> UInt32 {
        return (UInt32(_bytes[position++]) << 16) | (UInt32(_bytes[position++]) << 8) | UInt32(_bytes[position++])
    }

    func readUInt32() -> UInt32 {
        position += 4
        return UInt32(bytes: Array(_bytes[position - 4..<position])).bigEndian
    }

    func write(value:Int32) -> ByteArray {
        _bytes += value.bytes
        return self
    }

    func read(length:Int) -> String {
        position += length
        return String(bytes: Array(_bytes[position - length..<position]), encoding: NSUTF8StringEncoding)!
    }

    func write(value:String) -> ByteArray {
        _bytes += [UInt8](value.utf8)
        return self
    }

    func clear() {
        position = 0
        _bytes.removeAll(keepCapacity: false)
    }
}
