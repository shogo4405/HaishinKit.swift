import Foundation

struct MP4SampleDescriptionBox: MP4FullBox {
    static let audio: Set<String> = ["mp4a"]
    static let video: Set<String> = ["mp4v", "s263", "avc1"]

    static func makeEntry(by type: String) -> MP4SampleEntry? {
        switch true {
        case video.contains(type):
            return MP4VisualSampleEntry()
        case audio.contains(type):
            return MP4AudioSampleEntry()
        default:
            return nil
        }
    }

    static let flags: UInt32 = 0
    // MARK: MP4FullBox
    var size: UInt32 = 0
    let type: String = "stsd"
    var offset: UInt64 = 0
    var version: UInt8 = 0
    var flags: UInt32 = Self.flags
    // MARK: MP4SampleDescriptionBox
    var children: [MP4BoxConvertible] = []
}

extension MP4SampleDescriptionBox: DataConvertible {
    var data: Data {
        get {
            let buffer = ByteArray()
                .writeUInt32(size)
                .writeUTF8Bytes(type)
                .writeUInt8(version)
                .writeUInt24(flags)
                .writeUInt32(UInt32(children.count))
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
                _ = try buffer.readUTF8Bytes(4)
                version = try buffer.readUInt8()
                flags = try buffer.readUInt24()
                let numberOfEntries = try buffer.readUInt32()
                children.removeAll()
                for _ in 0..<numberOfEntries {
                    let size = try buffer.readUInt32()
                    let type = try buffer.readUTF8Bytes(4)
                    buffer.position -= 8
                    var entry = Self.makeEntry(by: type)
                    entry?.data = try buffer.readBytes(Int(size))
                    if let entry = entry {
                        children.append(entry)
                    }
                }
            } catch {
                logger.error(error)
            }
        }
    }
}

extension MP4Box.Names {
    static let stsd = MP4Box.Name<MP4SampleDescriptionBox>(rawValue: "stsd")
}
