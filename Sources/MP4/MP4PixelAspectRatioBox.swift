import Foundation

/// ISO/IEC 14496-12 5th 12.1.4.2
struct MP4PixelAspectRatioBox: MP4BoxConvertible {
    // MARK: MP4BoxConvertible
    var size: UInt32 = 0
    let type: String = "pasp"
    var offset: UInt64 = 0
    var children: [MP4BoxConvertible] = []
    // MARK: MP4PixelAspectRatioBox
    var hSpacing: UInt32 = 0
    var vSpacing: UInt32 = 0
}

extension MP4PixelAspectRatioBox: DataConvertible {
    var data: Data {
        get {
            let buffer = ByteArray()
                .writeUInt32(size)
                .writeUTF8Bytes(type)
                .writeUInt32(hSpacing)
                .writeUInt32(vSpacing)
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
                hSpacing = try buffer.readUInt32()
                vSpacing = try buffer.readUInt32()
            } catch {
                logger.error(error)
            }
        }
    }
}

extension MP4Box.Names {
    static let pasp = MP4Box.Name<MP4PixelAspectRatioBox>(rawValue: "pasp")
}
