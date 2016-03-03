import Foundation

final class RTMPChunk: NSObject {
    static let control:UInt16 = 0x02
    static let command:UInt16 = 0x03
    static let audio:UInt16 = 0x04
    static let video:UInt16 = 0x05
    static let maxTimestamp:UInt32 = 0xFFFFFF

    static func getStreamIdSize(byte:UInt8) -> Int {
        switch (byte & 0b00111111) {
        case 0:
            return 2
        case 1:
            return 3
        default:
            return 1
        }
    }

    enum Type:UInt8 {
        case Zero = 0
        case One = 1
        case Two = 2
        case Three = 3
        
        var headerSize:Int {
            switch self {
            case .Zero:
                return 11
            case .One:
                return 7
            case .Two:
                return 3
            case .Three:
                return 0
            }
        }

        func ready(bytes:[UInt8]) -> Bool {
            return headerSize + RTMPChunk.getStreamIdSize(bytes[0]) < bytes.count
        }

        func toBasicHeader(streamId:UInt16) -> [UInt8] {
            if (streamId <= 63) {
                return [rawValue << 6 | UInt8(streamId)]
            }
            if (streamId <= 319) {
                return [rawValue << 6 | 0b0000000, UInt8(streamId - 64)]
            }
            return [rawValue << 6 | 0b00111111] + (streamId - 64).bigEndian.bytes
        }
    }

    var type:Type = .Zero
    var streamId:UInt16 = RTMPChunk.command

    var ready:Bool  {
        if (message == nil) {
            return false
        }
        return message!.length == message!.payload.count
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

    private(set) var message:RTMPMessage?
    private(set) var fragmented:Bool = false

    private var _bytes:[UInt8] = []
    var bytes:[UInt8] {
        get {
            if (!_bytes.isEmpty) {
                return message == nil ? _bytes : _bytes + message!.payload
            }

            _bytes += type.toBasicHeader(streamId)
            _bytes += (RTMPChunk.maxTimestamp < message!.timestamp) ? [0xFF, 0xFF, 0xFF] : Array(message!.timestamp.bigEndian.bytes[1...3])
            _bytes += Array(UInt32(message!.payload.count).bigEndian.bytes[1...3])
            _bytes.append(message!.type.rawValue)

            if (type == .Zero) {
                _bytes += message!.streamId.littleEndian.bytes
            }

            if (RTMPChunk.maxTimestamp < message!.timestamp) {
                _bytes += message!.timestamp.bigEndian.bytes
            }

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
                streamId = UInt16(newValue[1]) + 64
            case 1:
                pos = 3
                streamId = UInt16(bytes: Array(newValue[1...2])) + 64
            default:
                pos = 1
                streamId = UInt16(newValue[0] & 0b00111111)
            }

            _bytes += Array(newValue[0..<headerSize])
            if (type == .Three) {
                return
            }

            let message:RTMPMessage = RTMPMessage.create(newValue[pos + 6])
            message.timestamp = UInt32(bytes: [0x00] + Array(newValue[pos..<pos + 3])).bigEndian

            switch type {
            case .Zero:
                message.length = Int(Int32(bytes: [0x00] + Array(newValue[pos + 3..<pos + 6])).bigEndian)
                message.streamId = UInt32(bytes: Array(newValue[pos + 7..<pos + headerSize]))
            case .One:
                message.length = Int(Int32(bytes: [0x00] + Array(newValue[pos + 3..<pos + 6])).bigEndian)
            default:
                break
            }

            var start:Int = headerSize
            if (message.timestamp == RTMPChunk.maxTimestamp) {
                message.timestamp = UInt32(bytes: Array(newValue[start..<start + 4])).bigEndian
                start += 4
            }
            message.payload = Array(newValue[start..<min(message.length + start, newValue.count)])

            self.message = message
        }
    }

    override var description:String {
        var description:String = "RTMPChunk{"
        description += "type:\(type.rawValue),"
        description += "streamId:\(streamId),"
        description += "message:\(message)"
        description += "}"
        return description
    }

    init?(bytes:[UInt8], size:Int) {
        super.init()
        if (bytes.isEmpty) {
            return nil
        }
        guard let type:Type = Type(rawValue: (bytes[0] & 0b11000000) >> 6) where type.ready(bytes) else {
            return nil
        }
        self.type = type
        self.bytes = bytes
    }

    init(type:Type, streamId:UInt16, message:RTMPMessage) {
        self.type = type
        self.streamId = streamId
        self.message = message
    }

    init(message:RTMPMessage) {
        self.message = message
    }

    func append(bytes:[UInt8], size:Int) -> Int {
        fragmented = false

        guard let message:RTMPMessage = message else {
            return 0
        }

        var length:Int = message.length - message.payload.count
        if (bytes.count < length) {
            length = bytes.count
        }

        let chunkSize:Int = size - (message.payload.count % size)
        if (chunkSize < length) {
            length = chunkSize
            fragmented = true
        }

        if (0 < length) {
            message.payload += Array(bytes[0..<length])
        }

        return length
    }

    func split(size:Int) -> [[UInt8]] {
        if (self.message == nil) {
            return [bytes]
        }

        let message:RTMPMessage = self.message!
        let length:Int = message.payload.count

        if (length < size) {
            return [bytes]
        }

        var total:Int = size + headerSize
        let basicHeader:[UInt8] = Type.Three.toBasicHeader(streamId)

        var result:[[UInt8]] = []
        result.append(Array(bytes[0..<total]))
        while (total + size < bytes.count) {
            result.append(basicHeader + Array(bytes[total..<total + size]))
            total += size
        }
        result.append(basicHeader + Array(bytes[total..<bytes.count]))

        return result
    }
}


