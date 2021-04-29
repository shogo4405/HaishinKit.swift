import Foundation

/// ISO/IEC 14496-12 5th 8.8.8.2
struct MP4TrackRunBox: MP4FullBox {
    struct Sample {
        var duration: UInt32?
        var size: UInt32?
        var flags: UInt32?
        var compositionTimeOffset: Int32?
    }
    enum Field: UInt32 {
        case dataOffset = 0x000001
        case firstSampleFlags = 0x000004
        case sampleDuration = 0x000100
        case sampleSize = 0x000200
        case sampleFlags = 0x000400
        case sampleCompositionTimeOffset = 0x000800
    }
    // MARK: MP4FullBox
    var size: UInt32 = 0
    let type: String = "trun"
    var offset: UInt64 = 0
    var children: [MP4BoxConvertible] = []
    var version: UInt8 = 0
    var flags: UInt32 = 0
    // MARK: MP4TrackRunBox
    var dataOffset: Int32 = 0
    var firstSampleFlags: UInt32 = 0
    var samples: [Sample] = []

    private func contains(_ value: Field) -> Bool {
        return (flags & value.rawValue) != 0
    }
}

extension MP4TrackRunBox: DataConvertible {
    var data: Data {
        get {
            Data()
        }
        set {
            do {
                let buffer = ByteArray(data: newValue)
                size = try buffer.readUInt32()
                _ = try buffer.readBytes(4)
                version = try buffer.readUInt8()
                flags = try buffer.readUInt24()
                let sampleCount: UInt32 = try buffer.readUInt32()
                if contains(.dataOffset) {
                    dataOffset = try buffer.readInt32()
                }
                if contains(.firstSampleFlags) {
                    firstSampleFlags = try buffer.readUInt32()
                }
                samples.removeAll()
                for _ in 0..<sampleCount {
                    samples.append(Sample(
                        duration: contains(.sampleDuration) ? try buffer.readUInt32() :  nil,
                        size: contains(.sampleSize) ? try buffer.readUInt32() : nil,
                        flags: contains(.sampleFlags) ? try buffer.readUInt32() : nil,
                        compositionTimeOffset: contains(.sampleCompositionTimeOffset) ? try buffer.readInt32() : nil
                    ))
                }
            } catch {
                logger.error(error)
            }
        }
    }
}

extension MP4Box.Names {
    static let trun = MP4Box.Name<MP4TrackRunBox>(rawValue: "trun")
}
