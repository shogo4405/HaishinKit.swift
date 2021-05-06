import Foundation

/// ISO/IEC 14496-12 5th 8.7.2.2
struct MP4DataEntryUrlBox: MP4FullBox {
    static let version: UInt8 = 0
    static let flags: UInt32 = 0
    // MARK: MP4FullBox
    var size: UInt32 = 0
    let type: String = "url "
    var offset: UInt64 = 0
    var version: UInt8 = Self.version
    var flags: UInt32 = Self.flags
    var children: [MP4BoxConvertible] = []
    // MARK: MP4DataEntryUrlBox
    var location: String = ""
}

extension MP4DataEntryUrlBox: DataConvertible {
    // MARK: DataConvertible
    var data: Data {
        get {
            let buffer = ByteArray()
                .writeUInt32(size)
                .writeUTF8Bytes(type)
                .writeUInt8(version)
                .writeUInt24(flags)
                .writeUTF8Bytes(location)
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
                location = try buffer.readUTF8Bytes(buffer.bytesAvailable)
            } catch {
                logger.error(error)
            }
        }
    }
}

extension MP4Box.Names {
    static let url = MP4Box.Name<MP4DataEntryUrlBox>(rawValue: "url ")
}
