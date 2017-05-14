import Foundation
import AVFoundation

enum FLVVideoCodec: UInt8 {
    case sorensonH263 = 2
    case screen1      = 3
    case on2VP6       = 4
    case on2VP6Alpha  = 5
    case screen2      = 6
    case avc          = 7
    case unknown      = 0xFF

    var isSupported:Bool {
        switch self {
        case .sorensonH263:
            return false
        case .screen1:
            return false
        case .on2VP6:
            return false
        case .on2VP6Alpha:
            return false
        case .screen2:
            return false
        case .avc:
            return true
        case .unknown:
            return false
        }
    }
}

enum FLVFrameType: UInt8 {
    case key        = 1
    case inter      = 2
    case disposable = 3
    case generated  = 4
    case command    = 5
}

enum FLVAVCPacketType:UInt8 {
    case seq = 0
    case nal = 1
    case eos = 2
}

enum FLVAACPacketType:UInt8 {
    case seq = 0
    case raw = 1
}

enum FLVSoundRate:UInt8 {
    case kHz5_5 = 0
    case kHz11  = 1
    case kHz22  = 2
    case kHz44  = 3
    
    var floatValue:Float64 {
        switch self {
        case .kHz5_5:
            return 5500
        case .kHz11:
            return 11025
        case .kHz22:
            return 22050
        case .kHz44:
            return 44100
        }
    }
}

enum FLVSoundSize:UInt8 {
    case snd8bit = 0
    case snd16bit = 1
}

enum FLVSoundType:UInt8 {
    case mono = 0
    case stereo = 1
}

enum FLVAudioCodec:UInt8 {
    case pcm           = 0
    case adpcm         = 1
    case mp3           = 2
    case pcmle         = 3
    case nellymoser16K = 4
    case nellymoser8K  = 5
    case nellymoser    = 6
    case g711A         = 7
    case g711MU        = 8
    case aac           = 10
    case speex         = 11
    case mp3_8k        = 14
    case unknown       = 0xFF
    
    var isSupported:Bool {
        switch self {
        case .pcm:
            return false
        case .adpcm:
            return false
        case .mp3:
            return false
        case .pcmle:
            return false
        case .nellymoser16K:
            return false
        case .nellymoser8K:
            return false
        case .nellymoser:
            return false
        case .g711A:
            return false
        case .g711MU:
            return false
        case .aac:
            return true
        case .speex:
            return false
        case .mp3_8k:
            return false
        case .unknown:
            return false
        }
    }
    
    var formatID:AudioFormatID {
        switch self {
        case .pcm:
            return kAudioFormatLinearPCM
        case .mp3:
            return kAudioFormatMPEGLayer3
        case .pcmle:
            return kAudioFormatLinearPCM
        case .aac:
            return kAudioFormatMPEG4AAC
        case .mp3_8k:
            return kAudioFormatMPEGLayer3
        default:
            return 0
        }
    }
    
    var headerSize:Int {
        switch self {
        case .aac:
            return 2
        default:
            return 1
        }
    }
}

// MARK: -
enum FLVTagType:UInt8 {
    case audio = 8
    case video = 9
    case data  = 18

    var streamId:UInt16 {
        switch self {
        case .audio:
            return RTMPChunk.StreamID.audio.rawValue
        case .video:
            return RTMPChunk.StreamID.video.rawValue
        case .data:
            return 0
        }
    }

    var headerSize:Int {
        switch self {
        case .audio:
            return 2
        case .video:
            return 5
        case .data:
            return 0
        }
    }

    func message(with streamId: UInt32, timestamp: UInt32, buffer:Data) -> RTMPMessage {
        switch self {
        case .audio:
            return RTMPAudioMessage(streamId: streamId, timestamp: timestamp, payload: buffer)
        case .video:
            return RTMPVideoMessage(streamId: streamId, timestamp: timestamp, payload: buffer)
        case .data:
            return RTMPDataMessage(objectEncoding: 0x00)
        }
    }

}

// MARK: -
struct FLVTag {
    static let headerSize = 11

    var tagType:FLVTagType = .data
    var dataSize:UInt32 = 0
    var timestamp:UInt32 = 0
    var timestampExtended:UInt8 = 0
    var streamId:UInt32 = 0

    init?(data:Data) {
        let buffer:ByteArray = ByteArray(data: data)
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
}

extension FLVTag: CustomStringConvertible {
    // MARK: CustomStringConvertible
    var description:String {
        return Mirror(reflecting: self).description
    }
}

final class FLVReader {
    static let header:Data = Data([0x46, 0x4C, 0x56, 1])

    private(set) var url:URL
    private(set) var hasAudio:Bool = false
    private(set) var hasVideo:Bool = false
    fileprivate var currentOffSet:UInt64 = 0
    fileprivate var fileHandle:FileHandle? = nil

    init(url:URL) {
        do {
            self.url = url
            fileHandle = try FileHandle(forReadingFrom: url)
            fileHandle?.seek(toFileOffset: 13)
            currentOffSet = 13
        } catch let error as NSError {
            logger.error("\(error)")
        }
    }
}

extension FLVReader: IteratorProtocol {
    func next() -> FLVTag? {
        guard let fileHandle:FileHandle = fileHandle else {
            return nil
        }
        let data:Data = fileHandle.readData(ofLength: FLVTag.headerSize)
        guard let tag:FLVTag = FLVTag(data: data) else {
            return nil
        }
        currentOffSet += UInt64(FLVTag.headerSize) + UInt64(tag.dataSize) + 4
        fileHandle.seek(toFileOffset: currentOffSet)
        return tag
    }
}
