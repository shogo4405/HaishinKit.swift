import Foundation

struct MP4ChunkOffsetBox: MP4FullBox {
    static let version: UInt8 = 0
    static let flags: UInt32 = 0
    // MARK: MP4FullBox
    var size: UInt32 = 0
    let type: String = "stco"
    var offset: UInt64 = 0
    var children: [MP4BoxConvertible] = []
    var version: UInt8 = Self.version
    var flags: UInt32 = Self.flags
    // MARK: MP4ChunkOffsetBox
    var entries: [UInt32] = []
}

extension MP4ChunkOffsetBox: DataConvertible {
    var data: Data {
        get {
            let buffer = ByteArray()
                .writeUInt32(size)
                .writeUTF8Bytes(type)
                .writeUInt8(version)
                .writeUInt24(flags)
                .writeUInt32(UInt32(entries.count))
            for entry in entries {
                buffer
                    .writeUInt32(entry)
            }
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
                let numberOfEntries = try buffer.readUInt32()
                entries.removeAll()
                for _ in 0..<numberOfEntries {
                    entries.append(try buffer.readUInt32())
                }
            } catch {
                logger.error(error)
            }
        }
    }
}

extension MP4Box.Names {
    static let stco = MP4Box.Name<MP4ChunkOffsetBox>(rawValue: "stco")
}
