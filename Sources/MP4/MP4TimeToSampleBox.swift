import Foundation

struct MP4TimeToSampleBox: MP4BoxConvertible {
    struct Entry: CustomDebugStringConvertible {
        let sampleCount: UInt32
        let sampleDuration: UInt32

        var debugDescription: String {
            Mirror(reflecting: self).debugDescription
        }
    }
    // MARK: MP4BoxConvertible
    var size: UInt32 = 0
    let type: String = "stts"
    var offset: UInt64 = 0
    var children: [MP4BoxConvertible] = []
    // MARK: MP4TimeToSampleBox
    var entries: [Entry] = []
}

extension MP4TimeToSampleBox: DataConvertible {
    var data: Data {
        get {
            Data()
        }
        set {
            do {
                let buffer = ByteArray(data: newValue)
                size = try buffer.readUInt32()
                _ = try buffer.readUTF8Bytes(4)
                entries.removeAll()
                let numberOfEntries: UInt32 = try buffer.readUInt32()
                for _ in 0..<numberOfEntries {
                    entries.append(Entry(
                        sampleCount: try buffer.readUInt32(),
                        sampleDuration: try buffer.readUInt32()
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
