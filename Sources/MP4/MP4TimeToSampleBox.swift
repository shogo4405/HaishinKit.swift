import Foundation

/// ISO/IEC 14496-12 5th 8.6.1.2.2
struct MP4TimeToSampleBox: MP4FullBox {
    static let version: UInt8 = 0
    static let flags: UInt32 = 0

    struct Entry: Equatable, CustomDebugStringConvertible {
        let sampleCount: UInt32
        let sampleDelta: UInt32

        var debugDescription: String {
            Mirror(reflecting: self).debugDescription
        }
    }
    // MARK: MP4FullBox
    var size: UInt32 = 0
    let type: String = "stts"
    var offset: UInt64 = 0
    var version: UInt8 = Self.version
    var flags: UInt32 = Self.flags
    var children: [MP4BoxConvertible] = []
    // MARK: MP4TimeToSampleBox
    var entries: [Entry] = []
}

extension MP4TimeToSampleBox: DataConvertible {
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
                    .writeUInt32(entry.sampleCount)
                    .writeUInt32(entry.sampleDelta)
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
                entries.removeAll()
                let numberOfEntries: UInt32 = try buffer.readUInt32()
                for _ in 0..<numberOfEntries {
                    entries.append(Entry(
                        sampleCount: try buffer.readUInt32(),
                        sampleDelta: try buffer.readUInt32()
                    ))
                }
            } catch {
                logger.error(error)
            }
        }
    }
}

extension MP4Box.Names {
    static let stts = MP4Box.Name<MP4TimeToSampleBox>(rawValue: "stts")
}
