import Foundation
import AVFoundation

class RTMPMessage {

    enum `Type`: UInt8 {
        case chunkSize   = 1
        case abort       = 2
        case ack         = 3
        case user        = 4
        case windowAck   = 5
        case bandwidth   = 6
        case audio       = 8
        case video       = 9
        case amf3Data    = 15
        case amf3Shared  = 16
        case amf3Command = 17
        case amf0Data    = 18
        case amf0Shared  = 19
        case amf0Command = 20
        case aggregate   = 22
        case unknown     = 255
    }

    static func create(_ value:UInt8) -> RTMPMessage? {
        switch value {
        case Type.chunkSize.rawValue:
            return RTMPSetChunkSizeMessage()
        case Type.abort.rawValue:
            return RTMPAbortMessge()
        case Type.ack.rawValue:
            return RTMPAcknowledgementMessage();
        case Type.user.rawValue:
            return RTMPUserControlMessage()
        case Type.windowAck.rawValue:
            return RTMPWindowAcknowledgementSizeMessage()
        case Type.bandwidth.rawValue:
            return RTMPSetPeerBandwidthMessage()
        case Type.audio.rawValue:
            return RTMPAudioMessage()
        case Type.video.rawValue:
            return RTMPVideoMessage()
        case Type.amf3Data.rawValue:
            return RTMPDataMessage(objectEncoding: 0x03)
        case Type.amf3Shared.rawValue:
            return RTMPSharedObjectMessage(objectEncoding: 0x03)
        case Type.amf3Command.rawValue:
            return RTMPCommandMessage(objectEncoding: 0x03)
        case Type.amf0Data.rawValue:
            return RTMPDataMessage(objectEncoding: 0x00)
        case Type.amf0Shared.rawValue:
            return RTMPSharedObjectMessage(objectEncoding: 0x00)
        case Type.amf0Command.rawValue:
            return RTMPCommandMessage(objectEncoding: 0x00)
        case Type.aggregate.rawValue:
            return RTMPAggregateMessage()
        default:
            guard let type:Type = Type(rawValue: value) else {
                logger.error("\(value)")
                return nil
            }
            return RTMPMessage(type: type)
        }
    }

    let type:Type
    var length:Int = 0
    var streamId:UInt32 = 0
    var timestamp:UInt32 = 0
    var payload:[UInt8] = []

    init(type:Type) {
        self.type = type
    }

    func execute(_ connection:RTMPConnection) {
    }
}

extension RTMPMessage: CustomStringConvertible {
    // MARK: CustomStringConvertible
    var description:String {
        return Mirror(reflecting: self).description
    }
}

// MARK: -
/**
 5.4.1. Set Chunk Size (1)
 */
final class RTMPSetChunkSizeMessage: RTMPMessage {
    var size:UInt32 = 0

    override var payload:[UInt8] {
        get {
            guard super.payload.isEmpty else {
                return super.payload
            }
            super.payload = size.bigEndian.bytes
            return super.payload
        }
        set {
            if (super.payload == newValue) {
                return
            }
            size = UInt32(bytes: newValue).bigEndian
            super.payload = newValue
        }
    }

    init() {
        super.init(type: .chunkSize)
    }

    init(size:UInt32) {
        super.init(type: .chunkSize)
        self.size = size
    }

    override func execute(_ connection:RTMPConnection) {
        connection.socket.chunkSizeC = Int(size)
    }
}

// MARK: -
/**
 5.4.2. Abort Message (2)
 */
final class RTMPAbortMessge: RTMPMessage {
    var chunkStreamId:UInt32 = 0

    override var payload:[UInt8] {
        get {
            guard super.payload.isEmpty else {
                return super.payload
            }
            super.payload = chunkStreamId.bigEndian.bytes
            return super.payload
        }
        set {
            if (super.payload == newValue) {
                return
            }
            chunkStreamId = UInt32(bytes: newValue).bigEndian
            super.payload = newValue
        }
    }

    init() {
        super.init(type: .abort)
    }
}

// MARK: -
/**
 5.4.3. Acknowledgement (3)
 */
final class RTMPAcknowledgementMessage: RTMPMessage {
    var sequence:UInt32 = 0
    
    override var payload:[UInt8] {
        get {
            guard super.payload.isEmpty else {
                return super.payload
            }
            super.payload = sequence.bigEndian.bytes
            return super.payload
        }
        set {
            if (super.payload == newValue) {
                return
            }
            sequence = UInt32(bytes: newValue).bigEndian
            super.payload = newValue
        }
    }

    init() {
        super.init(type: .ack)
    }
}

// MARK: -
/**
 5.4.4. Window Acknowledgement Size (5)
 */
final class RTMPWindowAcknowledgementSizeMessage: RTMPMessage {
    var size:UInt32 = 0

    init() {
        super.init(type: .windowAck)
    }

    init(size:UInt32) {
        super.init(type: .windowAck)
        self.size = size
    }

    override var payload:[UInt8] {
        get {
            guard super.payload.isEmpty else {
                return super.payload
            }
            super.payload = size.bigEndian.bytes
            return super.payload
        }
        set {
            if (super.payload == newValue) {
                return
            }
            size = UInt32(bytes: newValue).bigEndian
            super.payload = newValue
        }
    }

    override func execute(_ connection: RTMPConnection) {
        connection.socket.doOutput(chunk: RTMPChunk(
            type: .zero,
            streamId: RTMPChunk.StreamID.control.rawValue,
            message: RTMPWindowAcknowledgementSizeMessage(size: size)
        ))
    }
}

// MARK: -
/**
 5.4.5. Set Peer Bandwidth (6)
 */
final class RTMPSetPeerBandwidthMessage: RTMPMessage {
    
    enum Limit:UInt8 {
        case hard    = 0x00
        case soft    = 0x01
        case dynamic = 0x10
        case unknown = 0xFF
    }

    var size:UInt32 = 0
    var limit:Limit = .hard

    init() {
        super.init(type: .bandwidth)
    }

    override var payload:[UInt8] {
        get {
            guard super.payload.isEmpty else {
                return super.payload
            }
            var payload:[UInt8] = []
            payload += size.bigEndian.bytes
            payload += [limit.rawValue]
            super.payload = payload
            return super.payload
        }
        set {
            if (super.payload == newValue) {
                return
            }
            super.payload = newValue
        }
    }

    override func execute(_ connection: RTMPConnection) {
        connection.bandWidth = size
    }
}

// MARK: -
/**
 7.1.1. Command Message (20, 17)
 */
final class RTMPCommandMessage: RTMPMessage {

    let objectEncoding:UInt8
    var commandName:String = ""
    var transactionId:Int = 0
    var commandObject:ASObject? = nil
    var arguments:[Any?] = []

    override var payload:[UInt8] {
        get {
            guard super.payload.isEmpty else {
                return super.payload
            }
            if (type == .amf3Command) {
                serializer.writeUInt8(0)
            }
            serializer
                .serialize(commandName)
                .serialize(transactionId)
                .serialize(commandObject)
            for i in arguments {
                serializer.serialize(i)
            }
            super.payload = serializer.bytes
            serializer.clear()
            return super.payload
        }
        set {
            if (length == newValue.count) {
                serializer.writeBytes(newValue)
                serializer.position = 0
                do {
                    if (type == .amf3Command) {
                        serializer.position = 1
                    }
                    commandName = try serializer.deserialize()
                    transactionId = try serializer.deserialize()
                    commandObject = try serializer.deserialize()
                    arguments.removeAll()
                    if (0 < serializer.bytesAvailable) {
                        arguments.append(try serializer.deserialize())
                    }
                } catch {
                    logger.error("\(self.serializer)")
                }
                serializer.clear()
            }
            super.payload = newValue
        }
    }

    fileprivate var serializer:AMFSerializer = AMF0Serializer()

    init(objectEncoding:UInt8) {
        self.objectEncoding = objectEncoding
        super.init(type: objectEncoding == 0x00 ? .amf0Command : .amf3Command)
    }

    init(streamId:UInt32, transactionId:Int, objectEncoding:UInt8, commandName:String, commandObject: ASObject?, arguments:[Any?]) {
        self.transactionId = transactionId
        self.objectEncoding = objectEncoding
        self.commandName = commandName
        self.commandObject = commandObject
        self.arguments = arguments
        super.init(type: objectEncoding == 0x00 ? .amf0Command : .amf3Command)
        self.streamId = streamId
    }

    override func execute(_ connection: RTMPConnection) {

        guard let responder:Responder = connection.operations.removeValue(forKey: transactionId) else {
            switch commandName {
            case "close":
                connection.close()
            default:
                connection.dispatch(Event.RTMP_STATUS, bubbles: false, data: arguments.isEmpty ? nil : arguments[0])
            }
            return
        }

        switch commandName {
        case "_result":
            responder.on(result: arguments)
        case "_error":
            responder.on(status: arguments)
        default:
            break
        }
    }
}

// MARK: -
/**
 7.1.2. Data Message (18, 15)
 */
final class RTMPDataMessage: RTMPMessage {

    let objectEncoding:UInt8
    var handlerName:String = ""
    var arguments:[Any?] = []

    private var serializer:AMFSerializer = AMF0Serializer()

    override var payload:[UInt8] {
        get {
            guard super.payload.isEmpty else {
                return super.payload
            }

            if (type == .amf3Data) {
                serializer.writeUInt8(0)
            }
            serializer.serialize(handlerName)
            for arg in arguments {
                serializer.serialize(arg)
            }
            super.payload = serializer.bytes
            serializer.clear()

            return super.payload
        }
        set {
            guard super.payload != newValue else {
                return
            }

            if (length == newValue.count) {
                serializer.writeBytes(newValue)
                serializer.position = 0
                if (type == .amf3Data) {
                    serializer.position = 1
                }
                do {
                    handlerName = try serializer.deserialize()
                    while (0 < serializer.bytesAvailable) {
                        arguments.append(try serializer.deserialize())
                    }
                } catch {
                    logger.error("\(self.serializer)")
                }
                serializer.clear()
            }

            super.payload = newValue
        }
    }

    init(objectEncoding:UInt8) {
        self.objectEncoding = objectEncoding
        super.init(type: objectEncoding == 0x00 ? .amf0Data : .amf3Data)
    }

    init(streamId:UInt32, objectEncoding:UInt8, handlerName:String, arguments:[Any?] = []) {
        self.objectEncoding = objectEncoding
        self.handlerName = handlerName
        self.arguments = arguments
        super.init(type: objectEncoding == 0x00 ? .amf0Data : .amf3Data)
        self.streamId = streamId
    }

    override func execute(_ connection: RTMPConnection) {
        guard let stream:RTMPStream = connection.streams[streamId] else {
            return
        }
        OSAtomicAdd64(Int64(payload.count), &stream.info.byteCount)
    }
}

// MARK: -
/**
 7.1.3. Shared Object Message (19, 16)
 */
final class RTMPSharedObjectMessage: RTMPMessage {

    let objectEncoding:UInt8
    var sharedObjectName:String = ""
    var currentVersion:UInt32 = 0
    var flags:[UInt8] = [UInt8](repeating: 0x00, count: 8)
    var events:[RTMPSharedObjectEvent] = []

    override var payload:[UInt8] {
        get {
            guard super.payload.isEmpty else {
                return super.payload
            }

            if (type == .amf3Shared) {
                serializer.writeUInt8(0)
            }

            serializer
                .writeUInt16(UInt16(sharedObjectName.utf8.count))
                .writeUTF8Bytes(sharedObjectName)
                .writeUInt32(currentVersion)
                .writeBytes(flags)
            for event in events {
                event.serialize(&serializer)
            }
            super.payload = serializer.bytes
            serializer.clear()

            return super.payload
        }
        set {
            if (super.payload == newValue) {
                return
            }

            if (length == newValue.count) {
                serializer.writeBytes(newValue)
                serializer.position = 0
                if (type == .amf3Shared) {
                    serializer.position = 1
                }
                do {
                    sharedObjectName = try serializer.readUTF8()
                    currentVersion = try serializer.readUInt32()
                    flags = try serializer.readBytes(8)
                    while (0 < serializer.bytesAvailable) {
                        if let event:RTMPSharedObjectEvent = try RTMPSharedObjectEvent(serializer: &serializer) {
                            events.append(event)
                        }
                    }
                } catch {
                    logger.error("\(self.serializer)")
                }
                serializer.clear()
            }

            super.payload = newValue
        }
    }

    fileprivate var serializer:AMFSerializer = AMF0Serializer()

    init(objectEncoding:UInt8) {
        self.objectEncoding = objectEncoding
        super.init(type: objectEncoding == 0x00 ? .amf0Shared : .amf3Shared)
    }

    init(timestamp:UInt32, objectEncoding:UInt8, sharedObjectName:String, currentVersion:UInt32, flags:[UInt8], events:[RTMPSharedObjectEvent]) {
        self.objectEncoding = objectEncoding
        self.sharedObjectName = sharedObjectName
        self.currentVersion = currentVersion
        self.flags = flags
        self.events = events
        super.init(type: objectEncoding == 0x00 ? .amf0Shared : .amf3Shared)
        self.timestamp = timestamp
    }

    override func execute(_ connection:RTMPConnection) {
        let persistence:Bool = flags[0] == 0x01
        RTMPSharedObject.getRemote(withName: sharedObjectName, remotePath: connection.uri!.absoluteWithoutQueryString, persistence: persistence).on(message: self)
    }
}

// MARK: -
/**
 7.1.5. Audio Message (9)
 */
final class RTMPAudioMessage: RTMPMessage {
    var config:AudioSpecificConfig?

    private(set) var codec:FLVAudioCodec = .unknown
    private(set) var soundRate:FLVSoundRate = .kHz44
    private(set) var soundSize:FLVSoundSize = .snd8bit
    private(set) var soundType:FLVSoundType = .stereo

    var soundData:[UInt8] {
        let data:[UInt8] = payload.isEmpty ? [] : Array(payload[codec.headerSize..<payload.count])
        guard let config:AudioSpecificConfig = config else {
            return data
        }
        let adts:[UInt8] = config.adts(data.count)
        return adts + data
    }

    override var payload:[UInt8] {
        get {
            return super.payload
        }
        set {
            if (super.payload == newValue) {
                return
            }

            super.payload = newValue

            if (length == newValue.count && !newValue.isEmpty) {
                guard let codec:FLVAudioCodec = FLVAudioCodec(rawValue: newValue[0] >> 4),
                    let soundRate:FLVSoundRate = FLVSoundRate(rawValue: (newValue[0] & 0b00001100) >> 2),
                    let soundSize:FLVSoundSize = FLVSoundSize(rawValue: (newValue[0] & 0b00000010) >> 1),
                    let soundType:FLVSoundType = FLVSoundType(rawValue: (newValue[0] & 0b00000001)) else {
                    return
                }
                self.codec = codec
                self.soundRate = soundRate
                self.soundSize = soundSize
                self.soundType = soundType
            }
        }
    }

    init() {
        super.init(type: .audio)
    }

    init(streamId: UInt32, timestamp: UInt32, buffer:Data) {
        super.init(type: .audio)
        self.streamId = streamId
        self.timestamp = timestamp
        var payload:[UInt8] = [UInt8](repeating: 0x00, count: buffer.count)
        (buffer as NSData).getBytes(&payload, length: payload.count)
        self.payload = payload
    }

    override func execute(_ connection:RTMPConnection) {
        guard let stream:RTMPStream = connection.streams[streamId] else {
            return
        }
        OSAtomicAdd64(Int64(payload.count), &stream.info.byteCount)
        stream.audioPlayback.on(message: self)
    }

    func createAudioSpecificConfig() -> AudioSpecificConfig? {
        if (payload.isEmpty) {
            return nil
        }

        guard codec == FLVAudioCodec.aac else {
            return nil
        }

        if (payload[1] == FLVAACPacketType.seq.rawValue) {
            if let config:AudioSpecificConfig = AudioSpecificConfig(bytes: Array(payload[codec.headerSize..<payload.count])) {
                return config
            }
        }

        return nil
    }
}

// MARK: -
/**
 7.1.5. Video Message (9)
 */
final class RTMPVideoMessage: RTMPMessage {
    private(set) var codec:FLVVideoCodec = .unknown
    private(set) var status:OSStatus = noErr

    init() {
        super.init(type: .video)
    }

    init(streamId: UInt32, timestamp: UInt32, buffer:Data) {
        super.init(type: .video)
        self.streamId = streamId
        self.timestamp = timestamp
        payload = [UInt8](repeating: 0x00, count: buffer.count)
        (buffer as NSData).getBytes(&payload, length: payload.count)
    }

    override func execute(_ connection:RTMPConnection) {
        guard let stream:RTMPStream = connection.streams[streamId] else {
            return
        }
        OSAtomicAdd64(Int64(payload.count), &stream.info.byteCount)
        guard FLVTagType.video.headerSize < payload.count else {
            return
        }
        switch payload[1] {
        case FLVAVCPacketType.seq.rawValue:
            status = createFormatDescription(stream)
        case FLVAVCPacketType.nal.rawValue:
            enqueueSampleBuffer(stream)
        default:
            break
        }
    }

    func enqueueSampleBuffer(_ stream: RTMPStream) {
        stream.videoTimestamp += Double(timestamp)

        let compositionTimeoffset:Int32 = Int32(bytes: [0] + payload[2..<5]).bigEndian
        var timing:CMSampleTimingInfo = CMSampleTimingInfo(
            duration: CMTimeMake(Int64(timestamp), 1000),
            presentationTimeStamp: CMTimeMake(Int64(stream.videoTimestamp) + Int64(compositionTimeoffset), 1000),
            decodeTimeStamp: kCMTimeInvalid
        )

        let bytes:[UInt8] = Array(payload[FLVTagType.video.headerSize..<payload.count])
        var sample:[UInt8] = bytes
        let sampleSize:Int = bytes.count
        var blockBuffer:CMBlockBuffer?
        guard CMBlockBufferCreateWithMemoryBlock(
            kCFAllocatorDefault, &sample, sampleSize, kCFAllocatorNull, nil, 0, sampleSize, 0, &blockBuffer) == noErr else {
            return
        }
        var sampleBuffer:CMSampleBuffer?
        var sampleSizes:[Int] = [sampleSize]
        guard CMSampleBufferCreate(kCFAllocatorDefault, blockBuffer!, true, nil, nil, stream.mixer.videoIO.formatDescription, 1, 1, &timing, 1, &sampleSizes, &sampleBuffer) == noErr else {
            return
        }

        status = stream.mixer.videoIO.decoder.decodeSampleBuffer(sampleBuffer!)
    }

    func createFormatDescription(_ stream: RTMPStream) -> OSStatus {
        var config:AVCConfigurationRecord = AVCConfigurationRecord()
        config.bytes = Array(payload[FLVTagType.video.headerSize..<payload.count])
        return config.createFormatDescription(&stream.mixer.videoIO.formatDescription)
    }
}

// MARK: -
/**
 7.1.6. Aggregate Message (22)
 */
final class RTMPAggregateMessage: RTMPMessage {
    init() {
        super.init(type: .aggregate)
    }
}

// MARK: -
/**
 7.1.7. User Control Message Events
 */
final class RTMPUserControlMessage: RTMPMessage {

    enum Event: UInt8 {
        case streamBegin = 0x00
        case streamEof   = 0x01
        case streamDry   = 0x02
        case setBuffer   = 0x03
        case recorded    = 0x04
        case ping        = 0x06
        case pong        = 0x07
        case bufferEmpty = 0x1F
        case bufferFull  = 0x20
        case unknown     = 0xFF

        var bytes:[UInt8] {
            return [0x00, rawValue]
        }
    }

    var event:Event = .unknown
    var value:Int32 = 0

    override var payload:[UInt8] {
        get {
            guard super.payload.isEmpty else {
                return super.payload
            }
            super.payload.removeAll()
            super.payload += event.bytes
            super.payload += value.bigEndian.bytes
            return super.payload
        }
        set {
            if (super.payload == newValue) {
                return
            }
            if (length == newValue.count) {
                if let event:Event = Event(rawValue: newValue[1]) {
                    self.event = event
                }
                value = Int32(bytes: Array(newValue[2..<newValue.count])).bigEndian
            }
            super.payload = newValue
        }
    }

    init() {
        super.init(type: .user)
    }

    init(event:Event, value:Int32) {
        super.init(type: .user)
        self.event = event
        self.value = value
    }

    override func execute(_ connection: RTMPConnection) {
        switch event {
        case .ping:
            connection.socket.doOutput(chunk: RTMPChunk(
                type: .zero,
                streamId: RTMPChunk.StreamID.control.rawValue,
                message: RTMPUserControlMessage(event: .pong, value: value)
            ))
        case .bufferEmpty, .bufferFull:
            connection.streams[UInt32(value)]?.dispatch("rtmpStatus", bubbles: false, data: [
                "level": "status",
                "code": description,
                "description": ""
            ])
        default:
            break
        }
    }
}
