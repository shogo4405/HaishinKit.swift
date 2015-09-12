import Foundation

enum RTMPFrameType:UInt8 {
    case Key = 1
    case Inter = 2
    case Disposable = 3
    case Generated = 4
    case Command = 5
}

enum RTMPAVCPacketType:UInt8 {
    case Seq = 0
    case Nal = 1
    case Eos = 2
}

enum RTMPAACPacketType:UInt8 {
    case Seq = 0
    case Raw = 1
}

enum RTMPAudioCodec:UInt8 {
    case PCM = 0
    case ADPCM = 1
    case MP3 = 2
    case PCMLE = 3
    case Nellymoser16K = 4
    case Nellymoser8K = 5
    case Nellymoser = 6
    case G711A = 7
    case G711MU = 8
    case AAC = 10
    case Speex = 11
    case MP3_8k = 14
}

enum RTMPSoundRate:UInt8 {
    case KHz5_5 = 0
    case KHz11 = 1
    case KHz22 = 2
    case KHz44 = 3
}

enum RTMPSoundSize:UInt8 {
    case Snd8bit = 0
    case Snd16bit = 1
}

enum RTMPSoundType:UInt8 {
    case Mono = 0
    case Stereo = 1
}

enum RTMPVideoCodec:UInt8 {
    case SORENSON_H263 = 2
    case SCREEN_1 = 3
    case ON2_VP6 = 4
    case ON2_VP6_ALPHA = 5
    case SCREEN_2 = 6
    case AVC = 7
}

enum RTMPSampleType:UInt8 {
    case Video = 0
    case Audio = 1
    
    var headerSize:Int {
        switch self {
        case .Video:
            return 5
        case .Audio:
            return 2
        }
    }
}

struct FLVTag: CustomStringConvertible {

    enum Type:UInt8, CustomStringConvertible {
        case Audio = 8
        case Video = 9
        case Data  = 18
        case Unkown = 0xFF
        
        var description:String {
            switch self {
            case .Audio:
                return "audio"
            case .Video:
                return "video"
            case .Data:
                return "data"
            default:
                return "unknown"
            }
        }
    }

    static let headerSize = 11

    var type:Type = .Unkown
    var dataSize:UInt32 = 0
    var timestamp:UInt32 = 0
    var timestampExtended:UInt8 = 0
    var streamId:UInt32 = 0

    var description:String {
        var description = "FLVTag{"
        description += "type:\(type),"
        description += "dataSize:\(dataSize),"
        description += "timestamp:\(timestamp),"
        description += "timestampExtended:\(timestampExtended),"
        description += "streamId:\(streamId)"
        description += "}"
        return description
    }

    init(data:NSData) {
        let buffer:ByteArray = ByteArray(data: data)
        type = Type(rawValue: buffer.readUInt8())!
        dataSize = buffer.readUInt24()
        timestamp = buffer.readUInt24()
        timestampExtended = buffer.readUInt8()
        streamId = buffer.readUInt24()
        buffer.clear()
    }
}

class FLVFile {
    static let headerSize = 13
    static let signature:String = "FLV"

    var tags:[FLVTag] = []
    var version:UInt8 = 0

    func loadFile(fileHandle:NSFileHandle) {
        let buffer:ByteArray = ByteArray(data:fileHandle.readDataOfLength(FLVFile.headerSize))

        let signature:String = buffer.read(3)
        if (FLVFile.signature != signature) {
            return
        }
    }
}
