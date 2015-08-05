import Foundation

struct FLVTag: Printable {

    enum Type:UInt8, Printable {
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

    var type:Type = Type.Unkown
    var dataSize:UInt32 = 0
    var timestamp:UInt32 = 0
    var timestampExtended:UInt8 = 0
    var streamId:UInt32 = 0

    var description:String {
        var description = "FLVTag{"
        description += "type:" + type.description + ","
        description += "dataSize:" + dataSize.description + ","
        description += "timestamp:" + timestamp.description + ","
        description += "timestampExtended:" + timestampExtended.description + ","
        description += "streamId:" + streamId.description
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
        var buffer:ByteArray = ByteArray(data:fileHandle.readDataOfLength(FLVFile.headerSize))

        let signature:String = buffer.read(3)
        if (FLVFile.signature != signature) {
            return
        }
        
        while (true) {
            var tag:FLVTag = FLVTag(data:fileHandle.readDataOfLength(FLVTag.headerSize))
            fileHandle.seekToFileOffset(fileHandle.offsetInFile + UInt64(tag.dataSize))
            var tagSize:NSData = fileHandle.readDataOfLength(4)
            tags.append(tag)
        }
    }
}
