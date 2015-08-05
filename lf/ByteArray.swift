import Foundation

final class ByteArray: NSObject, Printable {
    private var _bytes:[UInt8] = []

    var bytes:[UInt8] {
        return _bytes
    }

    var length:Int {
        return _bytes.count
    }
    var position:Int = 0

    override var description:String {
        return _bytes.description
    }

    override init() {
    }

    init (data:NSData) {
        _bytes = [UInt8](count: data.length, repeatedValue: 0x00)
        data.getBytes(&_bytes, length: data.length)
    }

    func write(value:Int32) {
        _bytes += value.bytes
    }

    func write(value:[UInt8]) {
        _bytes += value
    }

    func writeUInt8(value:UInt8) {
        _bytes.append(value)
    }

    func readUInt8() -> UInt8 {
        return _bytes[position++]
    }

    func readUInt8(length:Int) -> [UInt8] {
        position += length
        return Array(_bytes[position - length..<position])
    }

    func readUInt16() -> UInt16 {
        position += 2
        return UInt16(bytes: Array(_bytes[position - 2..<position]).reverse())
    }

    func readUInt24() -> UInt32 {
        return (UInt32(_bytes[position++]) << 16) | (UInt32(_bytes[position++]) << 8) | UInt32(_bytes[position++])
    }

    func readUInt32() -> UInt32 {
        position += 4
        return UInt32(bytes: Array(_bytes[position - 4..<position]).reverse())
    }

    func read(length:Int) -> String {
        position += length
        return String(bytes: Array(_bytes[position - length..<position]), encoding: NSUTF8StringEncoding)!
    }

    func clear() {
        position = 0
        _bytes.removeAll(keepCapacity: false)
    }
}
