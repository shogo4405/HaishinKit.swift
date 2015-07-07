import Foundation

enum RTMPChunkType:UInt8 {
    case ZERO  = 0
    case ONE   = 1
    case TWO   = 2
    case THREE = 3

    var headerSize:Int {
        get {
            switch self {
            case .ZERO:
                return 11
            case .ONE:
                return 7
            case .TWO:
                return 3
            case .THREE:
                return 0
            }
        }
    }
}

enum RTMPChunkStreamId:UInt32 {
    case CONRTOL = 0x02
    case COMMAND = 0x03
    case AUDIO = 0x04
    case VIDEO = 0x05
}

final class RTMPChunk: NSObject {
    var type:RTMPChunkType = RTMPChunkType.ZERO
    var streamId:UInt32 = RTMPChunkStreamId.COMMAND.rawValue

    private var _message:RTMPMessage?

    var message:RTMPMessage? {
        return _message
    }
    
    var headerSize:Int {
        if (streamId <= 63) {
            return 1 + type.headerSize
        }
        if (streamId <= 319) {
            return 2 + type.headerSize
        }
        return 3 + type.headerSize
    }
    
    private var _bytes:[UInt8] = []
    
    var bytes:[UInt8] {
        get {
            if (!_bytes.isEmpty) {
                return message == nil ? _bytes : _bytes + message!.payload
            }

            _bytes.append(type.rawValue << 6 | UInt8(streamId))

            let timestamp:[UInt8] = message!.timestamp.bytes
            _bytes.append(timestamp[2])
            _bytes.append(timestamp[1])
            _bytes.append(timestamp[0])

            let length:[UInt8] = Int32(message!.payload.count).bytes
            _bytes.append(length[2])
            _bytes.append(length[1])
            _bytes.append(length[0])
            _bytes.append(message!.type.rawValue)

            if (type == RTMPChunkType.ONE) {
                return _bytes + message!.payload
            }
    
            let messageStreamId:[UInt8] = message!.streamId.bytes
            _bytes.append(messageStreamId[0])
            _bytes.append(messageStreamId[1])
            _bytes.append(messageStreamId[2])
            _bytes.append(messageStreamId[3])
            
            return _bytes + message!.payload
        }
        set {
            if (_bytes == newValue) {
                return
            }

            var pos:Int = 0
            switch (newValue[0] & 0b00111111) {
            case 0:
                pos = 2
                streamId = UInt32(newValue[1]) + 64
                break;
            case 1:
                pos = 5
                streamId = UInt32(bytes: Array(newValue[1...3])) + 64
                break;
            default:
                pos = 1
                streamId = UInt32(newValue[0] & 0b00111111)
                break;
            }

            _bytes += Array(newValue[0..<headerSize])
            if (self.type == RTMPChunkType.THREE) {
                return
            }

            var message:RTMPMessage = RTMPMessage.create(newValue[pos + 6])
            message.timestamp = UInt32(bytes: ([0x00] + Array(newValue[pos..<pos + 3])).reverse())

            if (self.type == RTMPChunkType.TWO) {
                return
            }

            message.length = Int(Int32(bytes: ([0x00] + Array(newValue[pos + 3..<pos + 6])).reverse()))

            if (self.type == RTMPChunkType.ZERO) {
                message.streamId = UInt32(bytes: Array(newValue[pos + 7...pos + headerSize - 1]))
            } else {
                message.streamId = streamId
            }

            let start:Int = headerSize
            var length:Int = message.length
            if (newValue.count < length) {
                length = newValue.count - start
            }
            message.payload = Array(newValue[start..<start + length])
            
            _message = message
        }
    }

    override var description:String {
        var description:String = "RTMPChunk{"
        description += "type:" + type.rawValue.description + ","
        description += "streamId:" + streamId.description + ","
        if (message == nil) {
            description += "message: nil"
        } else {
            description += "message:" + message!.description + ""
        }
        description += "}"
        return description
    }
    
    override init() {
    }
    
    init?(bytes:[UInt8]) {
        super.init()

        if (bytes.isEmpty || bytes[0] == 0) {
            return nil
        }

        let type:RTMPChunkType? = RTMPChunkType(rawValue: (bytes[0] & 0b11000000) >> 6)
        if (type == nil) {
            return nil
        }

        self.type = type!
        var require:Int = self.headerSize
        switch (bytes[0] & 0b00111111) {
        case 0:
            require += 2
            break
        case 1:
            require += 5
            break
        default:
            require += 1
            break
        }

        if (bytes.count <= require) {
            return nil
        }

        self.bytes = bytes
    }

    init(type:RTMPChunkType, streamId:UInt32, message:RTMPMessage) {
        self.type = type
        self.streamId = streamId
        _message = message
    }

    init(message:RTMPMessage) {
        _message = message
    }

    func split(chunkSize:Int) -> [[UInt8]] {
        if (self.message == nil) {
            return [bytes]
        }

        let message:RTMPMessage = self.message!
        let length:Int = message.payload.count

        if (length < chunkSize) {
            return [bytes]
        }

        var total:Int = chunkSize + headerSize
        var basicHeader:[UInt8] = []
        basicHeader.append(RTMPChunkType.THREE.rawValue << 6 | UInt8(streamId))

        var result:[[UInt8]] = []
        result.append(Array(bytes[0..<total]))
        while (total + chunkSize < bytes.count) {
            result.append(basicHeader + Array(bytes[total..<total + chunkSize]))
            total += chunkSize
        }
        result.append(basicHeader + Array(bytes[total..<bytes.count]))

        return result
    }
}

