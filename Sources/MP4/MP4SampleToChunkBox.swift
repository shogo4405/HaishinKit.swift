import Foundation

struct MP4SampleToChunkBox: MP4BoxConvertible {
    struct Entry: CustomDebugStringConvertible {
        let firstChunk: UInt32
        let samplesPerChunk: UInt32
        let sampleDescriptionIndex: UInt32

        var debugDescription: String {
            Mirror(reflecting: self).debugDescription
        }
    }
    // MARK: MP4BoxConvertible
    var size: UInt32 = 0
    let type: String = "stsc"
    var offset: UInt64 = 0
    var children: [MP4BoxConvertible] = []
    // MARK: MP4SampleToChunkBox
    var entries: [Entry] = []
}

extension MP4SampleToChunkBox: DataConvertible {
    var data: Data {
        get {
            Data()
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
