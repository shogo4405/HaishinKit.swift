import Foundation

struct MP4AudioSampleEntry: MP4SampleEntry {
    static let channelCount: UInt16 = 2
    static let sampleSize: UInt16 = 16
    // MARK: MP4SampleEntry
    var size: UInt32 = 0
    var type: String = ""
    var offset: UInt64 = 0
    var children: [MP4BoxConvertible] = []
    var dataReferenceIndex: UInt16 = 0
    // MARK: MP4AudioSampleEntry
    var channelCount: UInt16 = Self.channelCount
    var sampleSize: UInt16 = Self.sampleSize
    var sampleRate: UInt32 = 0
}

extension MP4AudioSampleEntry: DataConvertible {
    var data: Data {
        get {
            let buffer = ByteArray()
                .writeUInt32(size)
                .writeUTF8Bytes(type)
                .writeBytes(.init(repeating: 0, count: 6)) // const unsigned int(8)[6] reserved = 0
                .writeUInt16(dataReferenceIndex)
                .writeUInt32(0)
                .writeUInt32(0) // const unsigned int(32)[2] reserved = 0
                .writeUInt16(channelCount)
                .writeUInt16(sampleSize)
                .writeUInt16(0) // unsigned int(16) pre_defined = 0
                .writeUInt16(0) // const unsigned int(16) reserved = 0
                .writeUInt32(sampleRate << 16)
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
                buffer.position += 8
                channelCount = try buffer.readUInt16()
                sampleSize = try buffer.readUInt16()
                buffer.position += 4
                sampleRate = try buffer.readUInt32() >> 16
                children.removeAll()
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

extension MP4Box.Names {
    static let mp4a = MP4Box.Name<MP4AudioSampleEntry>(rawValue: "mp4a")
    static let mlpa = MP4Box.Name<MP4AudioSampleEntry>(rawValue: "mlpa")
}
