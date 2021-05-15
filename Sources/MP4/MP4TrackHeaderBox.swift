import Foundation

struct MP4TrackHeaderBox: MP4FullBox {
    static let layer: Int16 = 0
    static let volume: Int16 = 0x0100
    static let matrix: [Int32] = .init(repeating: 0, count: 9)
    // MARK: MP4FullBox
    var size: UInt32 = 0
    let type: String = "tkhd"
    var offset: UInt64 = 0
    var children: [MP4BoxConvertible] = []
    var version: UInt8 = 0
    var flags: UInt32 = 0
    // MARK: MP4MediaHeaderBox
    var creationTime: UInt64 = 0
    var modificationTime: UInt64 = 0
    var trackID: UInt32 = 0
    var duration: UInt64 = 0
    var layer: Int16 = 0
    var alternateGroup: Int16 = 0
    var volume: Int16 = Self.volume
    var matrix: [Int32] = Self.matrix
    var width: UInt32 = 0
    var height: UInt32 = 0
}

extension MP4TrackHeaderBox: DataConvertible {
    var data: Data {
        get {
            let buffer = ByteArray()
                .writeUInt32(size)
                .writeUTF8Bytes(type)
                .writeUInt8(version)
                .writeUInt24(flags)
            if version == 0 {
                buffer
                    .writeUInt32(UInt32(creationTime))
                    .writeUInt32(UInt32(modificationTime))
                    .writeUInt32(trackID)
                    .writeUInt32(0) // const unsigned int(32)  reserved = 0
                    .writeUInt32(UInt32(duration))
            } else {
                buffer
                    .writeUInt64(creationTime)
                    .writeUInt64(modificationTime)
                    .writeUInt32(trackID)
                    .writeUInt32(0) // const unsigned int(32)  reserved = 0
                    .writeUInt64(duration)
            }
            buffer
                .writeUInt32(0)
                .writeUInt32(0) // const unsigned int(32)[2]  reserved = 0
                .writeInt16(layer)
                .writeInt16(alternateGroup)
                .writeInt16(volume)
                .writeInt16(0)
            for m in matrix {
                buffer.writeInt32(m)
            }
            buffer
                .writeUInt32(width)
                .writeUInt32(height)
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
                if version == 0 {
                    creationTime = UInt64(try buffer.readUInt32())
                    modificationTime = UInt64(try buffer.readUInt32())
                    trackID = try buffer.readUInt32()
                    buffer.position += 4
                    duration = UInt64(try buffer.readUInt32())
                } else {
                    creationTime = try buffer.readUInt64()
                    modificationTime = try buffer.readUInt64()
                    trackID = try buffer.readUInt32()
                    buffer.position += 4
                    duration = try buffer.readUInt64()
                }
                buffer.position += 8
                layer = try buffer.readInt16()
                alternateGroup = try buffer.readInt16()
                volume = try buffer.readInt16()
                buffer.position += 2 // const unsigned int(16)  reserved = 0
                matrix.removeAll()
                for _ in 0..<9 {
                    matrix.append(try buffer.readInt32())
                }
                width = try buffer.readUInt32()
                height = try buffer.readUInt32()
            } catch {
                logger.error(error)
            }
        }
    }
}

extension MP4Box.Names {
    static let tkhd = MP4Box.Name<MP4TrackHeaderBox>(rawValue: "tkhd")
}
