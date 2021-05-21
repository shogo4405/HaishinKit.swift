import Foundation

struct MP4MovieFragmentHeaderBox: MP4FullBox {
    static let version: UInt8 = 0
    static let flags: UInt32 = 0
    // MARK: MP4FullBox
    var size: UInt32 = 0
    let type: String = "mfhd"
    var offset: UInt64 = 0
    var children: [MP4BoxConvertible] = []
    let version: UInt8 = Self.version
    let flags: UInt32 = Self.flags
    // MARK: MP4MovieFragmentHeaderBox
    var sequenceNumber: UInt32 = 0
}

extension MP4MovieFragmentHeaderBox: DataConvertible {
    var data: Data {
        get {
            let buffer = ByteArray()
                .writeUInt32(size)
                .writeUTF8Bytes(type)
                .writeUInt8(version)
                .writeUInt24(flags)
                .writeUInt32(sequenceNumber)
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
                sequenceNumber = try buffer.readUInt32()
            } catch {
                logger.error(error)
            }
        }
    }
}

extension MP4Box.Names {
    static let mfhd = MP4Box.Name<MP4MovieFragmentHeaderBox>(rawValue: "mfhd")
}
