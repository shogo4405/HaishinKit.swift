import Foundation

struct MP4MovieHeaderBox: MP4FullBox {
    static let rate: Int32 = 0x00010000
    static let volume: Int16 = 0x0100
    // MARK: MP4FullBox
    var size: UInt32 = 0
    let type: String = "mvhd"
    var offset: UInt64 = 0
    var children: [MP4BoxConvertible] = []
    var version: UInt8 = 0
    var flags: UInt32 = 0
    // MARK: MP4MediaHeaderBox
    var creationTime: UInt64 = 0
    var modificationTime: UInt64 = 0
    var timeScale: UInt32 = 0
    var duration: UInt64 = 0
    var rate: Int32 = Self.rate
    var volume: Int16 = Self.volume
    var matrix: [Int32] = []
    var nextTrackID: UInt32 = 0
}

extension MP4MovieHeaderBox: DataConvertible {
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
                .writeInt32(rate)
                .writeInt16(volume)
                .writeInt16(0)
                .writeUInt32(0)
                .writeUInt32(0)
            for m in matrix {
                buffer.writeInt32(m)
            }
            buffer
                .writeInt32(0)
                .writeInt32(0)
                .writeInt32(0)
                .writeInt32(0)
                .writeInt32(0)
                .writeInt32(0)
                .writeUInt32(nextTrackID)
            let size = buffer.position
            buffer.position = 0
            buffer.writeUInt32(UInt32(size))
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
                rate = try buffer.readInt32()
                volume = try buffer.readInt16()
                buffer.position += 2 // const bit(16) reserved
                buffer.position += 8 // const unsigned int(32)[2] reserved
                matrix.removeAll()
                for _ in 0..<9 {
                    matrix.append(try buffer.readInt32())
                }
                buffer.position += 24 // bit(32)[6] pre_defined = 0
                nextTrackID = try buffer.readUInt32()
            } catch {
                logger.error(error)
            }
        }
    }
}

extension MP4Box.Names {
    static let mvhd = MP4Box.Name<MP4MovieHeaderBox>(rawValue: "mvhd")
}
