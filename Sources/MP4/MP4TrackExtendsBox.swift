import Foundation

/// ISO/IEC 14496-12 5th 8.8.3.2
struct MP4TrackExtendsBox: MP4FullBox {
    static let version: UInt8 = 0
    static let flags: UInt32 = 0
    // MARK: MP4FullBox
    var size: UInt32 = 0
    let type: String = "trex"
    var offset: UInt64 = 0
    var version: UInt8 = Self.version
    var flags: UInt32 = Self.flags
    var children: [MP4BoxConvertible] = []
    // MARK: MP4MovieExtendsBox
    var trackID: UInt32 = 0
    var defaultSampleDescriptionIndex: UInt32 = 0
    var defaultSampleDuration: UInt32 = 0
    var defaultSampleSize: UInt32 = 0
    var defaultSampleFlags: UInt32 = 0
}

extension MP4TrackExtendsBox: DataConvertible {
    // MARK: DataConvertible
    var data: Data {
        get {
            let buffer = ByteArray()
                .writeUInt32(size)
                .writeUTF8Bytes(type)
                .writeUInt8(version)
                .writeUInt24(flags)
                .writeUInt32(trackID)
                .writeUInt32(defaultSampleDescriptionIndex)
                .writeUInt32(defaultSampleDuration)
                .writeUInt32(defaultSampleSize)
                .writeUInt32(defaultSampleFlags)
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
                trackID = try buffer.readUInt32()
                defaultSampleDescriptionIndex = try buffer.readUInt32()
                defaultSampleDuration = try buffer.readUInt32()
                defaultSampleSize = try buffer.readUInt32()
                defaultSampleFlags = try buffer.readUInt32()
            } catch {
                logger.error(error)
            }
        }
    }
}

extension MP4Box.Names {
    static let trex = MP4Box.Name<MP4TrackExtendsBox>(rawValue: "trex")
}
