import Foundation

enum RTMPChunkType: UInt8 {
    case zero = 0
    case one = 1
    case two = 2
    case three = 3

    var headerSize: Int {
        switch self {
        case .zero:
            return 11
        case .one:
            return 7
        case .two:
            return 3
        case .three:
            return 0
        }
    }

    func ready(_ data: Data) -> Bool {
        headerSize + RTMPChunk.getStreamIdSize(data[0]) < data.count
    }

    func toBasicHeader(_ streamId: UInt16) -> Data {
        if streamId <= 63 {
            return Data([rawValue << 6 | UInt8(streamId)])
        }
        if streamId <= 319 {
            return Data([rawValue << 6 | 0b0000000, UInt8(streamId - 64)])
        }
        return Data([rawValue << 6 | 0b00000001] + (streamId - 64).bigEndian.data)
    }
}

final class RTMPChunk {
    enum StreamID: UInt16 {
        case control = 0x02
        case command = 0x03
        case audio = 0x04
        case video = 0x05
        case data = 0x08
    }

    static let defaultSize: Int = 128
    static let maxTimestamp: UInt32 = 0xFFFFFF

    static func getStreamIdSize(_ byte: UInt8) -> Int {
        switch byte & 0b00111111 {
        case 0:
            return 2
        case 1:
            return 3
        default:
            return 1
        }
    }

    var size: Int = 0
    var type: RTMPChunkType = .zero
    var streamId: UInt16 = RTMPChunk.StreamID.command.rawValue

    var ready: Bool {
        guard let message: RTMPMessage = message else {
            return false
        }
        return message.length == message.payload.count
    }

    var headerSize: Int {
        if streamId <= 63 {
            return 1 + type.headerSize
        }
        if streamId <= 319 {
            return 2 + type.headerSize
        }
        return 3 + type.headerSize
    }

    var basicHeaderSize: Int {
        if streamId <= 63 {
            return 1
        }
        if streamId <= 319 {
            return 2
        }
        return 3
    }

    var data: Data {
        get {
            guard let message: RTMPMessage = message else {
                return _data
            }

            guard _data.isEmpty else {
                var data = Data()
                data.append(_data)
                data.append(message.payload)
                return data
            }

            _data.append(type.toBasicHeader(streamId))

            if RTMPChunk.maxTimestamp < message.timestamp {
                _data.append(contentsOf: [0xFF, 0xFF, 0xFF])
            } else {
                _data.append(contentsOf: message.timestamp.bigEndian.data[1...3])
            }
            _data.append(contentsOf: UInt32(message.payload.count).bigEndian.data[1...3])
            _data.append(message.type.rawValue)

            if type == .zero {
                _data.append(message.streamId.littleEndian.data)
            }

            if RTMPChunk.maxTimestamp < message.timestamp {
                _data.append(message.timestamp.bigEndian.data)
            }

            var data = Data()
            data.append(_data)
            data.append(message.payload)

            return data
        }
        set {
            if _data == newValue {
                return
            }

            var pos: Int = 0
            switch newValue[0] & 0b00111111 {
            case 0:
                pos = 2
                streamId = UInt16(newValue[1]) + 64
            case 1:
                pos = 3
                streamId = UInt16(data: newValue[1...2]) + 64
            default:
                pos = 1
                streamId = UInt16(newValue[0] & 0b00111111)
            }

            _data.append(newValue[0..<headerSize])

            if type == .two || type == .three {
                return
            }

            guard let message = RTMPMessageType(rawValue: newValue[pos + 6])?.makeMessage() else {
                logger.error(newValue.description)
                return
            }

            switch type {
            case .zero:
                message.timestamp = UInt32(data: newValue[pos..<pos + 3]).bigEndian
                message.length = Int(Int32(data: newValue[pos + 3..<pos + 6]).bigEndian)
                message.streamId = UInt32(data: newValue[pos + 7..<pos + 11])
            case .one:
                message.timestamp = UInt32(data: newValue[pos..<pos + 3]).bigEndian
                message.length = Int(Int32(data: newValue[pos + 3..<pos + 6]).bigEndian)
            default:
                break
            }

            var start: Int = headerSize
            if message.timestamp == RTMPChunk.maxTimestamp {
                message.timestamp = UInt32(data: newValue[start..<start + 4]).bigEndian
                start += 4
            }

            let end: Int = min(message.length + start, newValue.count)
            fragmented = size + start <= end
            message.payload = newValue.subdata(in: start..<min(size + start, end))

            self.message = message
        }
    }

    private(set) var message: RTMPMessage?
    private(set) var fragmented = false
    private var _data = Data()

    init(type: RTMPChunkType, streamId: UInt16, message: RTMPMessage) {
        self.type = type
        self.streamId = streamId
        self.message = message
    }

    init(message: RTMPMessage) {
        self.message = message
    }

    init?(_ data: Data, size: Int) {
        if data.isEmpty {
            return nil
        }
        guard let type = RTMPChunkType(rawValue: (data[0] & 0b11000000) >> 6), type.ready(data) else {
            return nil
        }
        self.size = size
        self.type = type
        self.data = data
    }

    func append(_ data: Data, size: Int) -> Int {
        fragmented = false

        guard let message = message else {
            return 0
        }

        var length: Int = message.length - message.payload.count

        if data.count < length {
            length = data.count
        }

        let chunkSize: Int = size - (message.payload.count % size)
        if chunkSize < length {
            length = chunkSize
        }

        if 0 < length {
            message.payload.append(data[0..<length])
        }

        fragmented = message.payload.count % size == 0

        return length
    }

    func append(_ data: Data, message: RTMPMessage?) -> Int {
        guard let message: RTMPMessage = message else {
            return 0
        }

        let buffer = ByteArray(data: data)
        buffer.position = basicHeaderSize

        do {
            self.message = message.type.makeMessage()
            self.message?.streamId = message.streamId
            self.message?.timestamp = self.type == .two ? try buffer.readUInt24() : message.timestamp
            self.message?.length = message.length
            self.message?.payload = Data(try buffer.readBytes(message.length))
        } catch {
            logger.warn("\(buffer)")
        }

        return headerSize + message.length
    }

    func split(_ size: Int) -> [Data] {
        let data: Data = self.data
        message?.length = data.count
        guard let message: RTMPMessage = message, size < message.payload.count else {
            return [data]
        }
        let startIndex: Int = size + headerSize
        let header: Data = RTMPChunkType.three.toBasicHeader(streamId)
        var chunks: [Data] = [data.subdata(in: 0..<startIndex)]
        for index in stride(from: startIndex, to: data.count, by: size) {
            var chunk: Data = header
            chunk.append(data.subdata(in: index..<index.advanced(by: index + size < data.count ? size : data.count - index)))
            chunks.append(chunk)
        }
        return chunks
    }
}

extension RTMPChunk: CustomDebugStringConvertible {
    // MARK: CustomDebugStringConvertible
    var debugDescription: String {
        Mirror(reflecting: self).debugDescription
    }
}
