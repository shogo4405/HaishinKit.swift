import Foundation

struct MP4MediaHeaderBox: MP4FullBox {
    // MARK: MP4FullBox
    var size: UInt32 = 0
    let type: String = "mdhd"
    var offset: UInt64 = 0
    var children: [MP4BoxConvertible] = []
    var version: UInt8 = 0
    var flags: UInt32 = 0
    // MARK: MP4MediaHeaderBox
    var creationTime: UInt64 = 0
    var modificationTime: UInt64 = 0
    var timeScale: UInt32 = 0
    var duration: UInt64 = 0
    var language: [UInt8] = [0, 0, 0]
}

extension MP4MediaHeaderBox: DataConvertible {
    var data: Data {
        get {
            let buffer = ByteArray()
                .writeUInt32(size)
                .writeUTF8Bytes(type)
                .writeUInt8(version)
                .writeUInt24(flags)
            if version == 0 {
                buffer
                    .writeUInt32(UInt32(creationTime))
                    .writeUInt32(UInt32(modificationTime))
                    .writeUInt32(timeScale)
                    .writeUInt32(UInt32(duration))
            } else {
                buffer
                    .writeUInt64(creationTime)
                    .writeUInt64(modificationTime)
                    .writeUInt32(timeScale)
                    .writeUInt64(duration)
            }
            buffer
                .writeUInt16(
                    UInt16(language[0]) << 10 |
                    UInt16(language[1]) << 5 |
                    UInt16(language[2])
                )
                .writeUInt16(0) // pre_defined = 0
            return buffer.data
        }
        set {
            do {
                let buffer = ByteArray(data: newValue)
                size = try buffer.readUInt32()
                _ = try buffer.readUTF8Bytes(4)
                version = try buffer.readUInt8()
                flags = try buffer.readUInt24()
                if version == 0 {
                    creationTime = UInt64(try buffer.readUInt32())
                    modificationTime = UInt64(try buffer.readUInt32())
                    timeScale = try buffer.readUInt32()
                    duration = UInt64(try buffer.readUInt32())
                } else {
                    creationTime = try buffer.readUInt64()
                    modificationTime = try buffer.readUInt64()
                    timeScale = try buffer.readUInt32()
                    duration = try buffer.readUInt64()
                }
                let lang = try buffer.readUInt16()
                language = [
                    UInt8((lang & 0x7C00) >> 10),
                    UInt8((lang & 0x3E0) >> 5),
                    UInt8(lang & 0x1F)
                ]
            } catch {
                logger.error(error)
            }
        }
    }
}

extension MP4Box.Names {
    static let mdhd = MP4Box.Name<MP4MediaHeaderBox>(rawValue: "mdhd")
}
