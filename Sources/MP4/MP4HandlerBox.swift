import Foundation

/// ISO/IEC 14496-12 5th 8.4.3.2
struct MP4HandlerBox: MP4FullBox {
    static let version: UInt8 = 0
    static let flags: UInt32 = 0
    // MARK: MP4FullBox
    var size: UInt32 = 0
    let type: String = "hdlr"
    var offset: UInt64 = 0
    var version: UInt8 = Self.version
    var flags: UInt32 = Self.flags
    var children: [MP4BoxConvertible] = []
    // MARK: MP4HandlerBox
    var handlerType: UInt32 = 0
    var name: String = ""
}

extension MP4HandlerBox: DataConvertible {
    // MARK: DataConvertible
    var data: Data {
        get {
            let buffer = ByteArray()
                .writeUInt32(size)
                .writeUTF8Bytes(type)
                .writeUInt8(version)
                .writeUInt24(flags)
                .writeUInt32(0) // pre_defined
                .writeUInt32(handlerType)
                .writeUInt32(0) // reserved
                .writeUInt32(0) // reserved
                .writeUInt32(0) // reserved
                .writeUTF8Bytes(name)
                .writeUTF8Bytes("\0")
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
                buffer.position += 4 // pre_defined
                handlerType = try buffer.readUInt32()
                buffer.position += 4 // reserved
                buffer.position += 4 // reserved
                buffer.position += 4 // reserved
                name = try buffer.readUTF8Bytes(buffer.bytesAvailable - 1)
            } catch {
                logger.error(error)
            }
        }
    }
}

extension MP4Box.Names {
    static let hdlr = MP4Box.Name<MP4HandlerBox>(rawValue: "hdlr")
}
