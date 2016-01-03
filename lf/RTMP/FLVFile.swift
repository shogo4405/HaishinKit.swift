import Foundation


struct FLVTag: CustomStringConvertible {

    enum TagType:UInt8 {
        case Audio = 8
        case Video = 9
        case Data  = 18

        var streamId:UInt16 {
            switch self {
            case .Audio:
                return RTMPChunk.audio
            case .Video:
                return RTMPChunk.video
            case .Data:
                return 0
            }
        }
        
        var headerSize:Int {
            switch self {
            case .Audio:
                return 2
            case .Video:
                return 5
            case .Data:
                return 0
            }
        }

        func createMessage(streamId: UInt32, timestamp: UInt32, buffer:NSData) -> RTMPMessage {
            switch self {
            case .Audio:
                return RTMPAudioMessage(streamId: streamId, timestamp: timestamp, buffer: buffer)
            case .Video:
                return RTMPVideoMessage(streamId: streamId, timestamp: timestamp, buffer: buffer)
            case .Data:
                return RTMPDataMessage()
            }
        }
    }

    enum FrameType:UInt8 {
        case Key = 1
        case Inter = 2
        case Disposable = 3
        case Generated = 4
        case Command = 5
    }
    
    enum AVCPacketType:UInt8 {
        case Seq = 0
        case Nal = 1
        case Eos = 2
    }
    
    enum AACPacketType:UInt8 {
        case Seq = 0
        case Raw = 1
    }
    
    enum AudioCodec:UInt8 {
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
    
    enum SoundRate:UInt8 {
        case KHz5_5 = 0
        case KHz11 = 1
        case KHz22 = 2
        case KHz44 = 3
    }
    
    enum SoundSize:UInt8 {
        case Snd8bit = 0
        case Snd16bit = 1
    }
    
    enum SoundType:UInt8 {
        case Mono = 0
        case Stereo = 1
    }
    
    enum VideoCodec:UInt8 {
        case SorensonH263 = 2
        case Screen1 = 3
        case ON2VP6 = 4
        case ON2VP6Alpha = 5
        case Screen2 = 6
        case AVC = 7
    }

    static let headerSize = 11

    var tagType:TagType = .Data
    var dataSize:UInt32 = 0
    var timestamp:UInt32 = 0
    var timestampExtended:UInt8 = 0
    var streamId:UInt32 = 0

    var description:String {
        var description = "FLVTag{"
        description += "tagType:\(tagType),"
        description += "dataSize:\(dataSize),"
        description += "timestamp:\(timestamp),"
        description += "timestampExtended:\(timestampExtended),"
        description += "streamId:\(streamId)"
        description += "}"
        return description
    }

    init(data:NSData) {
        let buffer:ByteArray = ByteArray(data: data)
        tagType = TagType(rawValue: buffer.readUInt8())!
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
