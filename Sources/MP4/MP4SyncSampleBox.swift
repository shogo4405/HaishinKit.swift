import Foundation

/// ISO/IEC 14496-12 5th 8.6.2.2
struct MP4SyncSampleBox: MP4FullBox {
    // MARK: MP4FullBox
    var size: UInt32 = 0
    let type: String = "stss"
    var offset: UInt64 = 0
    var children: [MP4BoxConvertible] = []
    var version: UInt8 = 0
    var flags: UInt32 = 0
    // MARK: MP4SyncSampleBox
    var entries: [UInt32] = []
}

extension MP4SyncSampleBox: DataConvertible {
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
                buffer.position += 4
                let numberOfEntries: UInt32 = try buffer.readUInt32()
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
    static let stss = MP4Box.Name<MP4SyncSampleBox>(rawValue: "stss")
}
