import Foundation

struct MP4SegmentIndexBox: MP4FullBox {
    static let flags: UInt32 = 0

    struct Reference: Equatable {
        var type = false
        var size: UInt32 = 0
        var subsegmentDuration: UInt32 = 0
        var startsWithSap = false
        var sapType: UInt8 = 0
        var sapDeltaTime: UInt32 = 0
    }

    // MARK: MP4FullBox
    var size: UInt32 = 0
    let type: String = "sidx"
    var offset: UInt64 = 0
    var children: [MP4BoxConvertible] = []
    var version: UInt8 = 0
    let flags: UInt32 = Self.flags
    // MARK: MP4SegmentIndexBox
    var referenceID: UInt32 = 0
    var timescale: UInt32 = 0
    var earliestPresentationTime: UInt64 = 0
    var firstOffset: UInt64 = 0
    var references: [Reference] = []
}

extension MP4SegmentIndexBox: DataConvertible {
    var data: Data {
        get {
            let buffer = ByteArray()
                .writeUInt32(size)
                .writeUTF8Bytes(type)
                .writeUInt8(version)
                .writeUInt24(flags)
                .writeUInt32(referenceID)
                .writeUInt32(timescale)
            if version == 0 {
                buffer
                    .writeUInt32(UInt32(earliestPresentationTime))
                    .writeUInt32(UInt32(firstOffset))
            } else {
                buffer
                    .writeUInt64(earliestPresentationTime)
                    .writeUInt64(firstOffset)
            }
            buffer
                .writeUInt16(0)
                .writeUInt16(UInt16(references.count))
            for reference in references {
                var first: UInt32 = 0
                let second = reference.subsegmentDuration
                var third: UInt32 = 0
                if reference.type {
                    first |= 1 << 31
                }
                first |= reference.size

                if reference.startsWithSap {
                    third |= 1 << 31
                }
                third |= UInt32(reference.sapType) << 28
                third |= reference.sapDeltaTime
                buffer
                    .writeUInt32(first)
                    .writeUInt32(second)
                    .writeUInt32(third)
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
                buffer.position += 3
                referenceID = try buffer.readUInt32()
                timescale = try buffer.readUInt32()
                if version == 0 {
                    earliestPresentationTime = UInt64(try buffer.readUInt32())
                    firstOffset = UInt64(try buffer.readUInt32())
                } else {
                    earliestPresentationTime = try buffer.readUInt64()
                    firstOffset = try buffer.readUInt64()
                }
                buffer.position += 2
                let referenceCount: UInt16 = try buffer.readUInt16()
                references.removeAll()
                for _ in 0..<referenceCount {
                    let first = try buffer.readUInt32()
                    let second = try buffer.readUInt32()
                    let third = try buffer.readUInt32()
                    references.append(Reference(
                        type: (first >> 31) == 1,
                        size: first & 0x7FFFFFFF,
                        subsegmentDuration: second,
                        startsWithSap: (third >> 31) == 1,
                        sapType: UInt8(third & 0x70000000 >> 28),
                        sapDeltaTime: third & 0xFFFFFFF
                    ))
                }
            } catch {
                logger.error(error)
            }
        }
    }
}

extension MP4Box.Names {
    static let sidx = MP4Box.Name<MP4SegmentIndexBox>(rawValue: "sidx")
}
