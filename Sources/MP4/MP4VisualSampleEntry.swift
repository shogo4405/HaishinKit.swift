import Foundation

/// ISO/IEC 14496-12 5th 12.1.3.2
struct MP4VisualSampleEntry: MP4SampleEntry {
    static let hSolution: UInt32 = 0x00480000
    static let vSolution: UInt32 = 0x00480000
    static let depth: UInt16 = 0x0018
    // MARK: MP4SampleEntry
    var size: UInt32 = 0
    var type: String = ""
    var offset: UInt64 = 0
    var children: [MP4BoxConvertible] = []
    var dataReferenceIndex: UInt16 = 0
    // MARK: MP4VisualSampleEntryBox
    var width: UInt16 = 0
    var height: UInt16 = 0
    var hSolution: UInt32 = Self.hSolution
    var vSolution: UInt32 = Self.vSolution
    var frameCount: UInt16 = 1
    var compressorname: String = ""
    var depth: UInt16 = Self.depth
}

extension MP4VisualSampleEntry: DataConvertible {
    var data: Data {
        get {
            let buffer = ByteArray()
                .writeUInt32(size)
                .writeUTF8Bytes(type)
                .writeBytes(.init(repeating: 0, count: 6)) // const unsigned int(8)[6] reserved = 0
                .writeUInt16(dataReferenceIndex)
                .writeUInt16(0) // unsigned int(16) pre_defined = 0
                .writeUInt16(0) // const unsigned int(16) reserved = 0
                .writeInt32(0)
                .writeInt32(0)
                .writeInt32(0) // unsigned int(32)[3]  pre_defined = 0
                .writeUInt16(width)
                .writeUInt16(height)
                .writeUInt32(hSolution)
                .writeUInt32(vSolution)
                .writeUInt32(0) //  const unsigned int(32)  reserved = 0
                .writeUInt16(frameCount)
                .writeUTF8Bytes(compressorname)
                .writeUInt16(depth)
                .writeInt16(-1) // int(16)  pre_defined = -1
            for child in children {
                buffer.writeBytes(child.data)
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
                type = try buffer.readUTF8Bytes(4)
                buffer.position += 6
                dataReferenceIndex = try buffer.readUInt16()
                buffer.position += 16
                width = try buffer.readUInt16()
                height = try buffer.readUInt16()
                hSolution = try buffer.readUInt32()
                vSolution = try buffer.readUInt32()
                buffer.position += 4
                frameCount = try buffer.readUInt16()
                compressorname = try buffer.readUTF8Bytes(32)
                depth = try buffer.readUInt16()
                _ = try buffer.readUInt16()
                while 0 < buffer.bytesAvailable {
                    let size = try buffer.readUInt32()
                    _ = try buffer.readUTF8Bytes(4)
                    buffer.position -= 8
                    var entry = MP4Box()
                    entry.data = try buffer.readBytes(Int(size))
                    children.append(entry)
                }
            } catch {
                logger.error(error)
            }
        }
    }
}
