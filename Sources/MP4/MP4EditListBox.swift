import Foundation

struct MP4EditListBox: MP4BoxConvertible {
    struct Entry: CustomDebugStringConvertible {
        let segmentDuration: UInt32
        let mediaTime: UInt32
        let mediaRate: UInt32

        var debugDescription: String {
            Mirror(reflecting: self).debugDescription
        }
    }
    // MARK: MP4BoxConvertible
    var size: UInt32 = 0
    let type: String = "elst"
    var offset: UInt64 = 0
    // MARK: MP4EditListBox
    var version: UInt32 = 0
    var entries: [Entry] = []
    var children: [MP4BoxConvertible] = []
}

extension MP4EditListBox: DataConvertible {
    var data: Data {
        get {
            Data()
        }
        set {
            do {
                let buffer = ByteArray(data: newValue)
                size = try buffer.readUInt32()
                _ = try buffer.readUTF8Bytes(4)
                version = try buffer.readUInt32()
                let numberOfEntries = try buffer.readUInt32()
                entries.removeAll()
                for _ in 0..<numberOfEntries {
                    entries.append(Entry(
                        segmentDuration: try buffer.readUInt32(),
                        mediaTime: try buffer.readUInt32(),
                        mediaRate: try buffer.readUInt32()
                    ))
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
