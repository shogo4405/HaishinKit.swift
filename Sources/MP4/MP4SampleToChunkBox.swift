import Foundation

/// ISO/IEC 14496-12 5th 8.7.4.2
struct MP4SampleToChunkBox: MP4FullBox {
    struct Entry: Equatable, CustomDebugStringConvertible {
        let firstChunk: UInt32
        let samplesPerChunk: UInt32
        let sampleDescriptionIndex: UInt32

        var debugDescription: String {
            Mirror(reflecting: self).debugDescription
        }
    }
    // MARK: MP4FullBox
    var size: UInt32 = 0
    let type: String = "stsc"
    var offset: UInt64 = 0
    var children: [MP4BoxConvertible] = []
    var version: UInt8 = 0
    var flags: UInt32 = 0
    // MARK: MP4SampleToChunkBox
    var entries: [Entry] = []
}

extension MP4SampleToChunkBox: DataConvertible {
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
                    .writeUInt32(entry.firstChunk)
                    .writeUInt32(entry.samplesPerChunk)
                    .writeUInt32(entry.sampleDescriptionIndex)
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
                    entries.append(Entry(
                        firstChunk: try buffer.readUInt32(),
                        samplesPerChunk: try buffer.readUInt32(),
                        sampleDescriptionIndex: try buffer.readUInt32()
                    ))
                }
            } catch {
                logger.error(error)
            }
        }
    }
}

extension MP4Box.Names {
    static let stsc = MP4Box.Name<MP4SampleToChunkBox>(rawValue: "stsc")
}
