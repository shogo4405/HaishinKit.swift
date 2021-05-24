import Foundation

struct DecoderConfigDescriptor: BaseDescriptor {
    static let tag: UInt8 = 0x04
    // MARK: BaseDescriptor
    let tag: UInt8 = Self.tag
    var size: UInt32 = 0
    // MARK: DecoderConfigDescriptor
    var objectTypeIndication: UInt8 = 0
    var streamType: UInt8 = 0
    var upStream = false
    var bufferSizeDB: UInt32 = 0
    var maxBitrate: UInt32 = 0
    var avgBitrate: UInt32 = 0
    var decSpecificInfo = DecoderSpecificInfo()
    var profileLevelIndicationIndexDescriptor = ProfileLevelIndicationIndexDescriptor()
}

extension DecoderConfigDescriptor: DataConvertible {
    // MARK: DataConvertible
    var data: Data {
        get {
            let buffer = ByteArray()
                .writeUInt8(tag)
                .writeUInt32(0)
                .writeUInt8(objectTypeIndication)
                .writeUInt8(streamType << 2 | (upStream ? 1 : 0) << 1 | 1)
                .writeUInt24(bufferSizeDB)
                .writeUInt32(maxBitrate)
                .writeUInt32(avgBitrate)
                .writeBytes(decSpecificInfo.data)
                .writeBytes(profileLevelIndicationIndexDescriptor.data)
            writeSize(buffer)
            return buffer.data
        }
        set {
            do {
                let buffer = ByteArray(data: newValue)
                _ = try buffer.readUInt8()
                size = try readSize(buffer)
                objectTypeIndication = try buffer.readUInt8()
                let first = try buffer.readUInt8()
                streamType = (first >> 2)
                upStream = (first & 2) != 0
                bufferSizeDB = try buffer.readUInt24()
                maxBitrate = try buffer.readUInt32()
                avgBitrate = try buffer.readUInt32()
                let position = buffer.position
                decSpecificInfo.data = try buffer.readBytes(buffer.bytesAvailable)
                buffer.position = position + Int(decSpecificInfo.size) + 5
                profileLevelIndicationIndexDescriptor.data = try buffer.readBytes(buffer.bytesAvailable)
            } catch {
                logger.error(error)
            }
        }
    }
}
