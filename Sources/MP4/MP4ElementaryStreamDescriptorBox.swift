import Foundation

/**
  - seealso: https://developer.apple.com/library/archive/documentation/QuickTime/QTFF/QTFFChap3/qtff3.html#//apple_ref/doc/uid/TP40000939-CH205-124774
 */
struct MP4ElementaryStreamDescriptorBox: MP4FullBox {
    // MARK: MP4FullBox
    var size: UInt32 = 0
    let type: String = "esds"
    var offset: UInt64 = 0
    var children: [MP4BoxConvertible] = []
    var version: UInt8 = 0
    var flags: UInt32 = 0
    // MARK: MP4FullBox
    var descriptor = ESDescriptor()
}

extension MP4ElementaryStreamDescriptorBox: DataConvertible {
    var data: Data {
        get {
            let buffer = ByteArray()
                .writeUInt32(size)
                .writeUTF8Bytes(type)
                .writeUInt8(version)
                .writeUInt24(flags)
                .writeBytes(descriptor.data)
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
                descriptor.data = try buffer.readBytes(buffer.bytesAvailable)
            } catch {
                logger.error(error)
            }
        }
    }
}

extension MP4Box.Names {
    static let esds = MP4Box.Name<MP4ElementaryStreamDescriptorBox>(rawValue: "esds")
}
