import Foundation

struct DecoderSpecificInfo: BaseDescriptor {
    static let tag: UInt8 = 0x05
    // MARK: BaseDescriptor
    let tag: UInt8 = Self.tag
    var size: UInt32 = 0
    // MARK: DecoderConfigDescriptor
    private var _data = Data()
}

extension DecoderSpecificInfo: DataConvertible {
    var data: Data {
        get {
            let buffer = ByteArray()
                .writeUInt8(tag)
                .writeUInt32(0)
                .writeBytes(_data)
            writeSize(buffer)
            return buffer.data
        }
        set {
            do {
                let buffer = ByteArray(data: newValue)
                _ = try buffer.readUInt8()
                size = try readSize(buffer)
                _data = try buffer.readBytes(Int(size))
            } catch {
                logger.error(error)
            }
        }
    }
}
