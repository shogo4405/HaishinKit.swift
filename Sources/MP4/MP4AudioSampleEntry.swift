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
            Data()
        }
        set {
            do {
                let buffer = ByteArray(data: newValue)
                size = try buffer.readUInt32()
                type = try buffer.readUTF8Bytes(4)
                buffer.position += 16
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
