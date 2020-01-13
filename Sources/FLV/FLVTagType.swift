import Foundation

public enum FLVTagType: UInt8 {
    case audio = 8
    case video = 9
    case data = 18

    var streamId: UInt16 {
        switch self {
        case .audio, .video:
            return UInt16(rawValue)
        case .data:
            return 0
        }
    }

    var headerSize: Int {
        switch self {
        case .audio:
            return 2
        case .video:
            return 5
        case .data:
            return 0
        }
    }
}

// MARK: -
public protocol FLVTag: CustomDebugStringConvertible {
    var tagType: FLVTagType { get set }
    var dataSize: UInt32 { get set }
    var timestamp: UInt32 { get set }
    var timestampExtended: UInt8 { get set }
    var streamId: UInt32 { get set }
    var offset: UInt64 { get set }

    init()
    mutating func readData(_ fileHandler: FileHandle)
}

extension FLVTag {
    var headerSize: Int {
        tagType.headerSize
    }

    init?(data: Data) {
        self.init()
        let buffer = ByteArray(data: data)
        do {
            tagType = FLVTagType(rawValue: try buffer.readUInt8()) ?? .data
            dataSize = try buffer.readUInt24()
            timestamp = try buffer.readUInt24()
            timestampExtended = try buffer.readUInt8()
            streamId = try buffer.readUInt24()
            buffer.clear()
        } catch {
            return nil
        }
    }

    // MARK: CustomDebugStringConvertible
    public var debugDescription: String {
        Mirror(reflecting: self).debugDescription
    }
}

// MARK: -
public struct FLVDataTag: FLVTag {
    public var tagType: FLVTagType = .data
    public var dataSize: UInt32 = 0
    public var timestamp: UInt32 = 0
    public var timestampExtended: UInt8 = 0
    public var streamId: UInt32 = 0
    public var offset: UInt64 = 0

    public init() {
    }

    public mutating func readData(_ fileHandler: FileHandle) {
    }
}

// MARK: -
public struct FLVAudioTag: FLVTag {
    public var tagType: FLVTagType = .audio
    public var dataSize: UInt32 = 0
    public var timestamp: UInt32 = 0
    public var timestampExtended: UInt8 = 0
    public var streamId: UInt32 = 0
    public var offset: UInt64 = 0
    public var codec: FLVAudioCodec = .unknown
    public var soundRate: FLVSoundRate = .kHz5_5
    public var soundSize: FLVSoundSize = .snd8bit
    public var soundType: FLVSoundType = .mono

    public init() {
    }

    public mutating func readData(_ fileHandler: FileHandle) {
        let data: Data = fileHandler.readData(ofLength: headerSize)
        codec = FLVAudioCodec(rawValue: data[0] >> 4) ?? .unknown
        soundRate = FLVSoundRate(rawValue: (data[0] & 0b00001100) >> 2) ?? .kHz5_5
        soundSize = FLVSoundSize(rawValue: (data[0] & 0b00000010) >> 1) ?? .snd8bit
        soundType = FLVSoundType(rawValue: data[0] & 0b00000001) ?? .mono
    }
}

// MARK: -
public struct FLVVideoTag: FLVTag {
    public var tagType: FLVTagType = .video
    public var dataSize: UInt32 = 0
    public var timestamp: UInt32 = 0
    public var timestampExtended: UInt8 = 0
    public var streamId: UInt32 = 0
    public var offset: UInt64 = 0
    public var frameType: FLVFrameType = .command
    public var codec: FLVVideoCodec = .unknown
    public var avcPacketType: FLVAVCPacketType = .eos
    public var compositionTime: Int32 = 0

    public init() {
    }

    public mutating func readData(_ fileHandler: FileHandle) {
        let data: Data = fileHandler.readData(ofLength: headerSize)
        frameType = FLVFrameType(rawValue: data[0] >> 4) ?? .command
        codec = FLVVideoCodec(rawValue: data[0] & 0b00001111) ?? .unknown
        avcPacketType = FLVAVCPacketType(rawValue: data[1]) ?? .eos
    }
}
