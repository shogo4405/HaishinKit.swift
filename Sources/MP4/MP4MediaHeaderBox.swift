import Foundation

struct MP4MediaHeaderBox: MP4BoxConvertible {
    // MARK: MP4BoxConvertible
    var size: UInt32 = 0
    var type: String = ""
    var offset: UInt64 = 0
    var children: [MP4BoxConvertible] = []
    // MARK: MP4MediaHeaderBox
    var version: UInt8 = 0
    var creationTime: UInt32 = 0
    var modificationTime: UInt32 = 0
    var timeScale: UInt32 = 0
    var duration: UInt32 = 0
    var language: UInt16 = 0
    var quality: UInt16 = 0
}

extension MP4MediaHeaderBox: DataConvertible {
    var data: Data {
        get {
            Data()
        }
        set {
            do {
                let buffer = ByteArray(data: newValue)
                size = try buffer.readUInt32()
                type = try buffer.readUTF8Bytes(4)
                version = try buffer.readUInt8()
                buffer.position += 3
                creationTime = try buffer.readUInt32()
                modificationTime = try buffer.readUInt32()
                timeScale = try buffer.readUInt32()
                duration = try buffer.readUInt32()
                language = try buffer.readUInt16()
                quality = try buffer.readUInt16()
            } catch {
                logger.error(error)
            }
        }
    }
}

extension MP4Box.Names {
    static let mvhd = MP4Box.Name<MP4MediaHeaderBox>(rawValue: "mvhd")
    static let mdhd = MP4Box.Name<MP4MediaHeaderBox>(rawValue: "mdhd")
}
