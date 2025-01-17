import AVFoundation
import Foundation
@testable import HaishinKit

/// The type of flv tag.
public enum FLVTagType: UInt8 {
    /// The Audio tag,
    case audio = 8
    /// The Video tag.
    case video = 9
    /// The Data tag.
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
/// The interface of FLV tag.
public protocol FLVTag: CustomDebugStringConvertible {
    /// The type of this tag.
    var tagType: FLVTagType { get set }
    /// The length of data int the field.
    var dataSize: UInt32 { get set }
    /// The timestamp in milliseconds.
    var timestamp: UInt32 { get set }
    /// The extension of the timestamp.
    var timestampExtended: UInt8 { get set }
    /// The streamId, always 0.
    var streamId: UInt32 { get set }
    /// The data offset of a flv file.
    var offset: UInt64 { get set }

    /// Initialize a new object.
    init()
    /// Read data of fileHandler.
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
/// A structure that defines the FLVTag of Data.
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
/// A structure that defines the FLVTag of an audio.
public struct FLVAudioTag: FLVTag {
    public var tagType: FLVTagType = .audio
    public var dataSize: UInt32 = 0
    public var timestamp: UInt32 = 0
    public var timestampExtended: UInt8 = 0
    public var streamId: UInt32 = 0
    public var offset: UInt64 = 0
    /// Specifies the codec of audio.
    public var codec: RTMPAudioCodec = .unknown
    /// Specifies the sound of rate.
    public var soundRate: RTMPSoundRate = .kHz5_5
    /// Specifies the sound of size.
    public var soundSize: RTMPSoundSize = .snd8bit
    /// Specifies the sound of type.
    public var soundType: RTMPSoundType = .mono

    public init() {
    }

    public mutating func readData(_ fileHandler: FileHandle) {
        let data: Data = fileHandler.readData(ofLength: headerSize)
        codec = RTMPAudioCodec(rawValue: data[0] >> 4) ?? .unknown
        soundRate = RTMPSoundRate(rawValue: (data[0] & 0b00001100) >> 2) ?? .kHz5_5
        soundSize = RTMPSoundSize(rawValue: (data[0] & 0b00000010) >> 1) ?? .snd8bit
        soundType = RTMPSoundType(rawValue: data[0] & 0b00000001) ?? .mono
    }
}

// MARK: -
/// A structure that defines the FLVTag of am video.
public struct FLVVideoTag: FLVTag {
    public var tagType: FLVTagType = .video
    public var dataSize: UInt32 = 0
    public var timestamp: UInt32 = 0
    public var timestampExtended: UInt8 = 0
    public var streamId: UInt32 = 0
    public var offset: UInt64 = 0
    /// Specifies the frame type of video.
    public var frameType: RTMPFrameType = .command
    /// Specifies the codec of video.
    public var codec: RTMPVideoCodec = .unknown
    /// Specifies the avc packet type.
    public var avcPacketType: RTMPAVCPacketType = .eos
    /// Specifies the composition time.
    public var compositionTime: Int32 = 0

    public init() {
    }

    public mutating func readData(_ fileHandler: FileHandle) {
        let data: Data = fileHandler.readData(ofLength: headerSize)
        frameType = RTMPFrameType(rawValue: data[0] >> 4) ?? .command
        codec = RTMPVideoCodec(rawValue: data[0] & 0b00001111) ?? .unknown
        avcPacketType = RTMPAVCPacketType(rawValue: data[1]) ?? .eos
    }
}

/// The FLVReader is used to read the contents of a FLV file.
public final class FLVReader {
    /// The header of a FLV.
    public static let header = Data([0x46, 0x4C, 0x56, 1])

    /// The headerSize of a FLV.
    static let headerSize: Int = 11

    /// The url of a FLV file.
    public let url: URL
    private var currentOffSet: UInt64 = 0
    private var fileHandle: FileHandle?

    /// Initializes and returns a newly allocated reader.
    public init(url: URL) {
        do {
            self.url = url
            fileHandle = try FileHandle(forReadingFrom: url)
            fileHandle?.seek(toFileOffset: 13)
            currentOffSet = 13
        } catch {
            logger.error(error)
        }
    }

    /// Returns data by FLVTag.
    public func getData(_ tag: any FLVTag) -> Data? {
        fileHandle?.seek(toFileOffset: tag.offset)
        return fileHandle?.readData(ofLength: Int(UInt64(tag.dataSize)))
    }
}

extension FLVReader: IteratorProtocol {
    // MARK: IteratorProtocol
    public func next() -> (any FLVTag)? {
        guard let fileHandle: FileHandle = fileHandle else {
            return nil
        }
        var tag: (any FLVTag)?
        fileHandle.seek(toFileOffset: currentOffSet)
        let data: Data = fileHandle.readData(ofLength: FLVReader.headerSize)
        guard !data.isEmpty else {
            return nil
        }
        switch data[0] {
        case 8:
            tag = FLVAudioTag(data: data)
        case 9:
            tag = FLVVideoTag(data: data)
        case 18:
            tag = FLVDataTag(data: data)
        default:
            return nil
        }
        tag?.readData(fileHandle)
        tag?.offset = currentOffSet + UInt64(FLVReader.headerSize)
        currentOffSet += UInt64(FLVReader.headerSize) + UInt64(tag!.dataSize) + 4
        return tag
    }
}
