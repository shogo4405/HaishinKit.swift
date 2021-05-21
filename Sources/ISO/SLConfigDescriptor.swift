import Foundation

struct SLConfigDescriptor: BaseDescriptor {
    // MARK: BaseDescriptor
    let tag: UInt8 = 0x06
    var size: UInt32 = 0
    // MARK: SLConfigDescriptor
    var predefined: UInt8 = 0
}

extension SLConfigDescriptor: DataConvertible {
    // MARK: DataConvertible
    var data: Data {
        get {
            let buffer = ByteArray()
                .writeUInt8(tag)
                .writeUInt32(0)
                .writeUInt8(predefined)
            writeSize(buffer)
            return buffer.data
        }
        set {
            do {
                let buffer = ByteArray(data: newValue)
                _ = try buffer.readUInt8()
                size = try readSize(buffer)
                predefined = try buffer.readUInt8()
            } catch {
                logger.error(error)
            }
        }
    }
}
