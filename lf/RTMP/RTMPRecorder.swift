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

        var isSupported:Bool {
            switch self {
            case .PCM:
                return false
            case .ADPCM:
                return false
            case .MP3:
                return false
            case .PCMLE:
                return false
            case .Nellymoser16K:
                return false
            case .Nellymoser8K:
                return false
            case .Nellymoser:
                return false
            case .G711A:
                return false
            case .G711MU:
                return false
            case .AAC:
                return true
            case .Speex:
                return false
            case .MP3_8k:
                return false
            }
        }
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

        var isSupported:Bool {
            switch self {
            case SorensonH263:
                return false
            case Screen1:
                return false
            case ON2VP6:
                return false
            case ON2VP6Alpha:
                return false
            case Screen2:
                return false
            case AVC:
                return true
            }
        }
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

    init (data:NSData) {
        let buffer:ByteArray = ByteArray(data: data)
        tagType = TagType(rawValue: buffer.readUInt8())!
        dataSize = buffer.readUInt24()
        timestamp = buffer.readUInt24()
        timestampExtended = buffer.readUInt8()
        streamId = buffer.readUInt24()
        buffer.clear()
    }
}

class RTMPRecorder: NSObject {

    static let defaultVersion:UInt8 = 1
    static let signature:String = "FLV"
    static let headerSize:UInt32 = 13

    private var version:UInt8 = RTMPRecorder.defaultVersion
    private var audioTimestamp:UInt32 = 0
    private var videoTimestamp:UInt32 = 0
    private var fileHandle:NSFileHandle? = nil
    private let lockQueue:dispatch_queue_t = dispatch_queue_create("com.github.shogo4405.lf.RTMPRecorder.lock", DISPATCH_QUEUE_SERIAL)

    func open(file:String, option:RTMPStream.RecordOption) {
        createFileIfNotExists(RTMPStream.rootPath + file + ".flv")
        fileHandle = option.createFileHandle(file)
        fileHandle?.seekToFileOffset(UInt64(RTMPRecorder.headerSize))
    }

    func close() {
        fileHandle?.closeFile()
    }

    func createFileIfNotExists(path: String) {
        let manager:NSFileManager = NSFileManager.defaultManager()
        guard !manager.fileExistsAtPath(path) else {
            return
        }
        do {
            let dir:String = (path as NSString).stringByDeletingLastPathComponent
            try manager.createDirectoryAtPath(dir, withIntermediateDirectories: true, attributes: nil)
            var header:[UInt8] = [0x46, 0x4C, 0x56, version, 0b00000101]
            header += UInt32(9).bigEndian.bytes
            header += UInt32(0).bigEndian.bytes
            manager.createFileAtPath(path, contents: NSData(bytes: &header, length: header.count), attributes: nil)
        } catch let error as NSError {
            print(error)
        }
    }

    func appendData(bytes:[UInt8]) {
        let data:NSData = NSData(bytes: bytes, length: bytes.count)
        fileHandle?.writeData(data)
    }

    func onMessage(audio message: RTMPAudioMessage) {
        var data:[UInt8] = [8]
        data += Array(UInt32(message.payload.count).bigEndian.bytes[1...3])
        data += Array(UInt32(audioTimestamp).bigEndian.bytes[1...3])
        data += [0]
        data += [0, 0, 0]
        data += message.payload
        data += UInt32(message.payload.count + 11).bigEndian.bytes
        appendData(data)
        audioTimestamp += message.timestamp
    }

    func onMessage(video message: RTMPVideoMessage) {
        var data:[UInt8] = [9]
        data += Array(UInt32(message.payload.count).bigEndian.bytes[1...3])
        data += Array(UInt32(videoTimestamp).bigEndian.bytes[1...3])
        data += [0]
        data += [0, 0, 0]
        data += message.payload
        data += UInt32(message.payload.count + 11).bigEndian.bytes
        print(videoTimestamp)
        appendData(data)
        videoTimestamp += message.timestamp
    }

    func onMessage(data message: RTMPDataMessage) {
    }
}
