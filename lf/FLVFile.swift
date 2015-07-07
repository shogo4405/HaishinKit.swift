import Foundation

enum FLVTagType:UInt8, Printable {
    case AUDIO = 8
    case VIDEO = 9
    case DATA  = 18
    case UNKOWN = 0xFF

    var description:String {
        switch self {
        case .AUDIO:
            return "audio"
        case .VIDEO:
            return "video"
        case .DATA:
            return "data"
        default:
            return "unknown"
        }
    }
}

struct FLVTag: Printable {

    static let headerSize = 11

    var type:FLVTagType = FLVTagType.UNKOWN
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
        var buffer:ByteArray = ByteArray(data: data)
        type = FLVTagType(rawValue: buffer.readUInt8())!
        dataSize = buffer.readUInt24()
        timestamp = buffer.readUInt24()
        timestampExtended = buffer.readUInt8()
        streamId = buffer.readUInt24()
        buffer.clear()
    }
}

public class FLVFile {
    static let headerSize = 13
    static let signature:String = "FLV"

    var tags:[FLVTag] = []
    var version:UInt8 = 0

    public init() {
    }

    public func loadFile(fileHandle:NSFileHandle) {
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
