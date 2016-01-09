import Foundation

final class ByteArray: CustomStringConvertible {
    private var _bytes:[UInt8] = []
    var bytes:[UInt8] {
        return _bytes
    }

    var position:Int = 0

    var length:Int {
        get {
            return _bytes.count
        }
        set {
            switch true {
            case (_bytes.count < newValue):
                _bytes += [UInt8](count: newValue - _bytes.count, repeatedValue: 0)
            case (newValue < bytes.count):
                _bytes = Array(_bytes[0..<newValue])
            default:
                break
            }
        }
    }

    var description:String {
        return _bytes.description
    }

    subscript(i: Int) -> UInt8 {
        get {
            return _bytes[i]
        }
        set {
            _bytes[i] = newValue
        }
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

    func sequence(length:Int, lambda:(ByteArray -> Void)) {
        let r:Int = (_bytes.count - position) % length
        for index in _bytes.startIndex.advancedBy(position).stride(to: _bytes.endIndex.advancedBy(-r), by: length) {
            lambda(ByteArray(bytes: Array(_bytes[index..<index.advancedBy(length)])))
        }
        if (0 < r) {
            lambda(ByteArray(bytes: Array(_bytes[_bytes.endIndex - r..<_bytes.endIndex])))
        }
     }

    func clear() {
        position = 0
        _bytes.removeAll(keepCapacity: false)
    }

    func toUInt32() -> [UInt32] {
        let size:Int = sizeof(UInt32)
        if ((_bytes.endIndex - position) % size != 0) {
            return []
        }
        var result:[UInt32] = []
        for index in _bytes.startIndex.advancedBy(position).stride(to: _bytes.endIndex, by: size) {
            result.append(UInt32(bytes: Array(_bytes[index..<index.advancedBy(size)])))
        }
        return result
    }
}
