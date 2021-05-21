import Foundation

/// ISO/IEC 14496-15 5.3.4.1.2
struct MP4AVCConfigurationBox: MP4BoxConvertible {
    // MARK: MP4BoxConvertible
    var size: UInt32 = 0
    let type: String = "avcC"
    var offset: UInt64 = 0
    var children: [MP4BoxConvertible] = []
    // MARK: MP4AVCConfigurationBox
    var config = AVCConfigurationRecord()
}

extension MP4AVCConfigurationBox: DataConvertible {
    var data: Data {
        get {
            let buffer = ByteArray()
                .writeUInt32(size)
                .writeUTF8Bytes(type)
                .writeBytes(config.data)
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
                config = AVCConfigurationRecord(data: try buffer.readBytes(buffer.bytesAvailable))
            } catch {
                logger.error(error)
            }
        }
    }
}

extension MP4Box.Names {
    static let avcC = MP4Box.Name<MP4PixelAspectRatioBox>(rawValue: "avcC")
}
