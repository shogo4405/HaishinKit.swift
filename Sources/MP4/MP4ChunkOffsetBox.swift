import Foundation

struct MP4ChunkOffsetBox: MP4BoxConvertible {
    // MARK: MP4BoxConvertible
    var size: UInt32 = 0
    let type: String = "stco"
    var offset: UInt64 = 0
    var children: [MP4BoxConvertible] = []
    // MARK: MP4ChunkOffsetBox
    var entries: [UInt32] = []
}

extension MP4ChunkOffsetBox: DataConvertible {
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
