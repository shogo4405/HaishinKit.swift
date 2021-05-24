import Foundation

protocol BaseDescriptor: Equatable, DataConvertible, CustomDebugStringConvertible {
    var tag: UInt8 { get }
    var size: UInt32 { get }
}

extension BaseDescriptor {
    func writeSize(_ byteArray: ByteArray) {
        let bytes = UInt32(byteArray.position - 5).bigEndian.data.bytes
        byteArray.position = 1
        for i in 0..<bytes.count - 1 {
            byteArray.writeUInt8(bytes[i] | 0x80)
        }
        if let last = bytes.last {
            byteArray.writeUInt8(last)
        }
    }

    func readSize(_ byteArray: ByteArray) throws -> UInt32 {
        var size: UInt32 = 0
        var length: UInt8 = 0
        repeat {
            length = try byteArray.readUInt8()
            size += size << 7 | UInt32(length & 0x7F)
        } while ((length & 0x80) != 0)
        return size
    }
}

extension BaseDescriptor {
    // MARK: CustomDebugStringConvertible
    var debugDescription: String {
        Mirror(reflecting: self).debugDescription
    }
}
