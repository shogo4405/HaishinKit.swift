import Foundation

struct MP4TrackFragmentBaseMediaDecodeTimeBox: MP4BoxConvertible {
    static let flags: UInt32 = 0
    // MARK: MP4FullBox
    var size: UInt32 = 0
    let type: String = "tfdt"
    var offset: UInt64 = 0
    var children: [MP4BoxConvertible] = []
    var version: UInt8 = 0
    let flags: UInt32 = Self.flags
    // MARK: MP4TrackFragmentBaseMediaDecodeTimeBox
    var baseMediaDecodeTime: UInt64 = 0
}

extension MP4TrackFragmentBaseMediaDecodeTimeBox: DataConvertible {
    var data: Data {
        get {
            let buffer = ByteArray()
                .writeUInt32(size)
                .writeUTF8Bytes(type)
                .writeUInt8(version)
                .writeUInt24(flags)
            if version == 0 {
                buffer.writeUInt32(UInt32(baseMediaDecodeTime))
            } else {
                buffer.writeUInt64(baseMediaDecodeTime)
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
                if version == 0 {
                    baseMediaDecodeTime = UInt64(try buffer.readUInt32())
                } else {
                    baseMediaDecodeTime = try buffer.readUInt64()
                }
            } catch {
                logger.error(error)
            }
        }
    }
}

extension MP4Box.Names {
    static let tfdt = MP4Box.Name<MP4TrackFragmentBaseMediaDecodeTimeBox>(rawValue: "tfdt")
}
