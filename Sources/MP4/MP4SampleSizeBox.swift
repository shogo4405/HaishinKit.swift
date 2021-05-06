import Foundation

/// ISO/IEC 14496-12 5th 8.7.3.2.1
struct MP4SampleSizeBox: MP4FullBox {
    // MARK: MP4FullBox
    var size: UInt32 = 0
    let type: String = "stsz"
    var offset: UInt64 = 0
    var children: [MP4BoxConvertible] = []
    var version: UInt8 = 0
    var flags: UInt32 = 0
    // MARK: MP4SampleSizeBox
    var sampleSize: UInt32 = 0
    var entries: [UInt32] = []
}

extension MP4SampleSizeBox: DataConvertible {
    var data: Data {
        get {
            let buffer = ByteArray()
                .writeUInt32(size)
                .writeUTF8Bytes(type)
                .writeUInt8(version)
                .writeUInt24(flags)
                .writeUInt32(sampleSize)
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
                version = try buffer.readUInt8()
                flags = try buffer.readUInt24()
                sampleSize = try buffer.readUInt32()
                entries.removeAll()
                let numberOfEntries = try buffer.readUInt32()
                if sampleSize == 0 {
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
