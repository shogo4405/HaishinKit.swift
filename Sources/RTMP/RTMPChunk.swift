import Foundation

final class RTMPChunk {
    static let control:UInt16 = 0x02
    static let command:UInt16 = 0x03
    static let audio:UInt16 = 0x04
    static let video:UInt16 = 0x05
    static let maxTimestamp:UInt32 = 0xFFFFFF

    static let defaultSize:Int = 128

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

    enum Type: UInt8 {
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

    var size:Int = 0
    var type:Type = .Zero
    var streamId:UInt16 = RTMPChunk.command

    var ready:Bool {
        guard let message:RTMPMessage = message else {
            return false
        }
        return message.length == message.payload.count
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

    var basicHeaderSize:Int {
        if (streamId <= 63) {
            return 1
        }
        if (streamId <= 319) {
            return 2
        }
        return 3
    }

    private(set) var message:RTMPMessage?
    private(set) var fragmented:Bool = false
    private var _bytes:[UInt8] = []

    init(type:Type, streamId:UInt16, message:RTMPMessage) {
        self.type = type
        self.streamId = streamId
        self.message = message
    }

    init(message:RTMPMessage) {
        self.message = message
    }

    init?(bytes:[UInt8], size:Int) {
        if (bytes.isEmpty) {
            return nil
        }
        guard let type:Type = Type(rawValue: (bytes[0] & 0b11000000) >> 6) where type.ready(bytes) else {
            return nil
        }
        self.size = size
        self.type = type
        self.bytes = bytes
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
        }

        if (0 < length) {
            message.payload.appendContentsOf(bytes[0..<length])
        }

        fragmented = message.payload.count % size == 0

        return length
    }

    func append(bytes:[UInt8], message: RTMPMessage?) -> Int {
        guard let message:RTMPMessage = message else {
            return 0
        }

        let buffer:ByteArray = ByteArray(bytes: bytes)
        buffer.position = basicHeaderSize

        do {
            self.message = RTMPMessage.create(message.type.rawValue)
            self.message?.streamId = message.streamId
            self.message?.timestamp = try buffer.readUInt24()
            self.message?.length = message.length
            self.message?.payload = try buffer.readBytes(message.length)
        } catch {
            logger.warning("\(buffer)")
        }

        return headerSize + message.length
    }

    func split(size:Int) -> [[UInt8]] {
        let bytes:[UInt8] = self.bytes
        message?.length = bytes.count

        guard let message:RTMPMessage = message where size < message.payload.count else {
            return [bytes]
        }

        let header:[UInt8] = Type.Three.toBasicHeader(streamId)
        let startIndex:Int = size + headerSize

        var result:[[UInt8]] = []
        result.append(Array(bytes[0..<startIndex]))
        for index in startIndex.stride(to: bytes.count, by: size) {
            var headerCombine:[UInt8] = header
            headerCombine.appendContentsOf(bytes[index..<index.advancedBy(size, limit: bytes.count)])
            result.append(headerCombine)
        }

        return result
    }
}

// MARK: CustomStringConvertible
extension RTMPChunk: CustomStringConvertible {
    var description:String {
        return Mirror(reflecting: self).description
    }
}

// MARK: BytesConvertible
extension RTMPChunk: BytesConvertible {
    var bytes:[UInt8] {
        get {
            guard let message:RTMPMessage = message else {
                return _bytes
            }

            guard _bytes.isEmpty else {
                var bytes:[UInt8] = _bytes
                bytes.appendContentsOf(message.payload)
                return bytes
            }

            _bytes += type.toBasicHeader(streamId)
            _bytes += (RTMPChunk.maxTimestamp < message.timestamp) ? [0xFF, 0xFF, 0xFF] : Array(message.timestamp.bigEndian.bytes[1...3])
            _bytes += Array(UInt32(message.payload.count).bigEndian.bytes[1...3])
            _bytes.append(message.type.rawValue)

            if (type == .Zero) {
                _bytes += message.streamId.littleEndian.bytes
            }

            if (RTMPChunk.maxTimestamp < message.timestamp) {
                _bytes += message.timestamp.bigEndian.bytes
            }

            var bytes:[UInt8] = _bytes
            bytes.appendContentsOf(message.payload)

            return bytes
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

            if (type == .Two || type == .Three) {
                return
            }

            guard let message:RTMPMessage = RTMPMessage.create(newValue[pos + 6]) else {
                logger.error(newValue.description)
                return
            }

            switch type {
            case .Zero:
                message.timestamp = UInt32(bytes: [0x00] + Array(newValue[pos..<pos + 3])).bigEndian
                message.length = Int(Int32(bytes: [0x00] + Array(newValue[pos + 3..<pos + 6])).bigEndian)
                message.streamId = UInt32(bytes: Array(newValue[pos + 7..<pos + headerSize]))
            case .One:
                message.timestamp = UInt32(bytes: [0x00] + Array(newValue[pos..<pos + 3])).bigEndian
                message.length = Int(Int32(bytes: [0x00] + Array(newValue[pos + 3..<pos + 6])).bigEndian)
            default:
                break
            }

            var start:Int = headerSize
            if (message.timestamp == RTMPChunk.maxTimestamp) {
                message.timestamp = UInt32(bytes: Array(newValue[start..<start + 4])).bigEndian
                start += 4
            }

            let end:Int = min(message.length + start, newValue.count)
            fragmented = size + start < end
            message.payload = Array(newValue[start..<min(size + start, end)])

            self.message = message
        }
    }
}
