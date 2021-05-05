import Foundation

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
            Data()
        }
        set {
            do {
                let buffer = ByteArray(data: newValue)
                size = try buffer.readUInt32()
                type = try buffer.readUTF8Bytes(4)
                buffer.position += 24
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
