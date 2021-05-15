import Foundation

struct MP4EditListBox: MP4FullBox {
    static let flags: UInt32 = 0

    struct Entry: Equatable, CustomDebugStringConvertible {
        let segmentDuration: UInt64
        let mediaTime: UInt64
        let mediaRateInteger: Int16
        let mediaRateFraction: Int16

        var debugDescription: String {
            Mirror(reflecting: self).debugDescription
        }
    }

    // MARK: MP4FullBox
    var size: UInt32 = 0
    let type: String = "elst"
    var offset: UInt64 = 0
    var children: [MP4BoxConvertible] = []
    var version: UInt8 = 0
    var flags: UInt32 = Self.flags
    // MARK: MP4EditListBox
    var entries: [Entry] = []
}

extension MP4EditListBox: DataConvertible {
    var data: Data {
        get {
            let buffer = ByteArray()
                .writeUInt32(size)
                .writeUTF8Bytes(type)
                .writeUInt8(version)
                .writeUInt24(flags)
                .writeUInt32(UInt32(entries.count))
            for entry in entries {
                if version == 0 {
                    buffer
                        .writeUInt32(UInt32(entry.segmentDuration))
                        .writeUInt32(UInt32(entry.mediaTime))
                        .writeInt16(entry.mediaRateInteger)
                        .writeInt16(entry.mediaRateFraction)
                } else {
                    buffer
                        .writeUInt64(entry.segmentDuration)
                        .writeUInt64(entry.mediaTime)
                        .writeInt16(entry.mediaRateInteger)
                        .writeInt16(entry.mediaRateFraction)
                }
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
                    if version == 0 {
                        entries.append(Entry(
                            segmentDuration: UInt64(try buffer.readUInt32()),
                            mediaTime: UInt64(try buffer.readUInt32()),
                            mediaRateInteger: try buffer.readInt16(),
                            mediaRateFraction: try buffer.readInt16()
                        ))
                    } else {
                        entries.append(Entry(
                            segmentDuration: try buffer.readUInt64(),
                            mediaTime: try buffer.readUInt64(),
                            mediaRateInteger: try buffer.readInt16(),
                            mediaRateFraction: try buffer.readInt16()
                        ))
                    }
                }
            } catch {
                logger.error(error)
            }
        }
    }
}

extension MP4Box.Names {
    static let elst = MP4Box.Name<MP4EditListBox>(rawValue: "elst")
}
