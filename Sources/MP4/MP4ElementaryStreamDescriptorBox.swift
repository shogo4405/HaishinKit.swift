import Foundation

struct MP4ElementaryStreamDescriptorBox: MP4BoxConvertible {
    // MARK: MP4ContainerBoxConvertible
    var size: UInt32 = 0
    let type: String = "esds"
    var offset: UInt64 = 0
    var children: [MP4BoxConvertible] = []
    // MARK: MP4ElementaryStreamDescriptorBox
    var audioDecorderSpecificConfig = Data()
    var tag: UInt8 = 0
    var tagSize: UInt8 = 0
    var id: UInt16 = 0
    var streamDependenceFlag: UInt8 = 0
    var urlFlag: UInt8 = 0
    var ocrStreamFlag: UInt8 = 0
    var streamPriority: UInt8 = 0
}

extension MP4ElementaryStreamDescriptorBox: DataConvertible {
    var data: Data {
        get {
            Data()
        }
        set {
            do {
                let buffer = ByteArray(data: newValue)
                size = try buffer.readUInt32()
                _ = try buffer.readUTF8Bytes(4)
                tag = try buffer.readUInt8()
                self.tagSize = try buffer.readUInt8()
                if self.tagSize == 0x80 {
                    buffer.position += 2
                    self.tagSize = try buffer.readUInt8()
                }
                id = try buffer.readUInt16()
                let data: UInt8 = try buffer.readUInt8()
                streamDependenceFlag = data >> 7
                urlFlag = (data >> 6) & 0x1
                ocrStreamFlag = (data >> 5) & 0x1
                streamPriority = data & 0x1f
                if streamDependenceFlag == 1 {
                    let _: UInt16 = try buffer.readUInt16()
                }
                // Decorder Config Descriptor
                let _: UInt8 = try buffer.readUInt8()
                tagSize = try buffer.readUInt8()
                if tagSize == 0x80 {
                    buffer.position += 2
                    tagSize = try buffer.readUInt8()
                }
                buffer.position += 13
                // Audio Decorder Spec Info
                let _: UInt8 = try buffer.readUInt8()
                tagSize = try buffer.readUInt8()
                if tagSize == 0x80 {
                    buffer.position += 2
                    tagSize = try buffer.readUInt8()
                }
                audioDecorderSpecificConfig = try buffer.readBytes(Int(tagSize))
            } catch {
                logger.error(error)
            }
        }
    }
}

extension MP4Box.Names {
    static let esds = MP4Box.Name<MP4ElementaryStreamDescriptorBox>(rawValue: "esds")
}
