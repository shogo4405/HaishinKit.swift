import Foundation

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
