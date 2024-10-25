import Foundation

struct MoQTPayload {
    private(set) var data = Data()

    enum Error: Swift.Error {
        case eof
        case outOfRange
    }

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

    init() {
    }

    init(_ data: Data) {
        self.data = data
    }

    @discardableResult
    mutating func putInt(_ value: Int) -> Self {
        if value <= 63 {
            return putData(UInt8(value).bigEndian.data)
        }
        if value <= 16383 {
            return putData((UInt16(value) | 0x4000).bigEndian.data)
        }
        if value <= 1073741823 {
            return putData((UInt32(value) | 0x80000000).bigEndian.data)
        }
        return putData((UInt64(value) | 0xc000000000000000).bigEndian.data)
    }

    mutating func getInt() throws -> Int {
        guard 1 <= bytesAvailable else {
            throw Error.eof
        }
        switch Int(data[position] >> 6) {
        case 0:
            defer {
                position += 1
            }
            return Int(data: data[position..<position + 1]).bigEndian
        case 1:
            defer {
                position += 2
            }
            return Int(data: data[position..<position + 2]).bigEndian & 0x3FFF
        case 2:
            defer {
                position += 4
            }
            return Int(data: data[position..<position + 4]).bigEndian
        case 3:
            defer {
                position += 8
            }
            return Int(data: data[position..<position + 8]).bigEndian & 0x1FFFFFFFFFFFFFFF
        default:
            throw Error.outOfRange
        }
    }

    @discardableResult
    mutating func putString(_ value: String) -> Self {
        putInt(value.utf8.count)
        putData(Data(value.utf8))
        return self
    }

    mutating func getString() throws -> String {
        let length = try getInt()
        let data = try getData(length)
        return String(data: data, encoding: .utf8) ?? ""
    }

    mutating func putBool(_ value: Bool) -> Self {
        putData(Data([value ? 1 : 0]))
        return self
    }

    mutating func getBool() throws -> Bool {
        guard 1 <= bytesAvailable else {
            throw Error.eof
        }
        let value = try getData(1)
        return value[0] == 1
    }

    @discardableResult
    mutating func putData(_ value: Data) -> Self {
        if position == data.count {
            data.append(value)
            position = data.count
            return self
        }
        let length = min(data.count - position, value.count)
        data.replaceSubrange(position..<position + length, with: value)
        position += value.count
        return self
    }

    mutating func getData(_ length: Int) throws -> Data {
        guard length <= bytesAvailable else {
            throw Error.eof
        }
        position += length
        return data.subdata(in: position - length..<position)
    }
}
