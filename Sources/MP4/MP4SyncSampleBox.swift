import Foundation

struct MP4SyncSampleBox: MP4BoxConvertible {
    // MARK: MP4BoxConvertible
    var size: UInt32 = 0
    let type: String = "stss"
    var offset: UInt64 = 0
    // MARK: MP4SyncSampleBox
    var entries: [UInt32] = []
    var children: [MP4BoxConvertible] = []
}

extension MP4SyncSampleBox: DataConvertible {
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
