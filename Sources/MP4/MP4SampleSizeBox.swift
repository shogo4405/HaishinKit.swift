import Foundation

struct MP4SampleSizeBox: MP4BoxConvertible {
    // MARK: MP4BoxConvertible
    var size: UInt32 = 0
    let type: String = "stsz"
    var offset: UInt64 = 0
    var children: [MP4BoxConvertible] = []
    // MARK: MP4SampleSizeBox
    var entries: [UInt32] = []
}

extension MP4SampleSizeBox: DataConvertible {
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
                entries.removeAll()
                let sampleSize = try buffer.readUInt32()
                if sampleSize == 0 {
                    let numberOfEntries: UInt32 = try buffer.readUInt32()
                    for _ in 0..<numberOfEntries {
                        entries.append(try buffer.readUInt32())
                    }
                } else {
                    entries.append(sampleSize)
                }
            } catch {
                logger.error(error)
            }
        }
    }
}

extension MP4Box.Names {
    static let stsz = MP4Box.Name<MP4SampleSizeBox>(rawValue: "stsz")
}
