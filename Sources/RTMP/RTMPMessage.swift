import AVFoundation

class RTMPMessage {

    enum `Type`: UInt8 {
        case chunkSize = 0x01
        case abort = 0x02
        case ack = 0x03
        case user = 0x04
        case windowAck = 0x05
        case bandwidth = 0x06
        case audio = 0x08
        case video = 0x09
        case amf3Data = 0x0F
        case amf3Shared = 0x10
        case amf3Command = 0x11
        case amf0Data = 0x12
        case amf0Shared = 0x13
        case amf0Command = 0x14
        case aggregate = 0x16
        case unknown = 0xFF
    }

    static func create(_ value: UInt8) -> RTMPMessage? {
        switch `Type`(rawValue: value) {
        case .chunkSize?:
            return RTMPSetChunkSizeMessage()
        case .abort?:
            return RTMPAbortMessge()
        case .ack?:
            return RTMPAcknowledgementMessage()
        case .user?:
            return RTMPUserControlMessage()
        case .windowAck?:
            return RTMPWindowAcknowledgementSizeMessage()
        case .bandwidth?:
            return RTMPSetPeerBandwidthMessage()
        case .audio?:
            return RTMPAudioMessage()
        case .video?:
            return RTMPVideoMessage()
        case .amf3Data?:
            return RTMPDataMessage(objectEncoding: 0x03)
        case .amf3Shared?:
            return RTMPSharedObjectMessage(objectEncoding: 0x03)
        case .amf3Command?:
            return RTMPCommandMessage(objectEncoding: 0x03)
        case .amf0Data?:
            return RTMPDataMessage(objectEncoding: 0x00)
        case .amf0Shared?:
            return RTMPSharedObjectMessage(objectEncoding: 0x00)
        case .amf0Command?:
            return RTMPCommandMessage(objectEncoding: 0x00)
        case .aggregate?:
            return RTMPAggregateMessage()
        default:
            guard let type = Type(rawValue: value) else {
                logger.error("\(value)")
                return nil
            }
            return RTMPMessage(type: type)
        }
    }

    let type: Type
    var length: Int = 0
    var streamId: UInt32 = 0
    var timestamp: UInt32 = 0
    var payload = Data()

    init(type: Type) {
        self.type = type
    }

    func execute(_ connection: RTMPConnection, type: RTMPChunkType) {
    }
}

extension RTMPMessage: CustomStringConvertible {
    // MARK: CustomStringConvertible
    var description: String {
        return Mirror(reflecting: self).description
    }
}

// MARK: -
/**
 5.4.1. Set Chunk Size (1)
 */
final class RTMPSetChunkSizeMessage: RTMPMessage {
    var size: UInt32 = 0

    override var payload: Data {
        get {
            guard super.payload.isEmpty else {
                return super.payload
            }
            super.payload = size.bigEndian.data
            return super.payload
        }
        set {
            if super.payload == newValue {
                return
            }
            size = UInt32(data: newValue).bigEndian
            super.payload = newValue
        }
    }

    init() {
        super.init(type: .chunkSize)
    }

    init(_ size: UInt32) {
        super.init(type: .chunkSize)
        self.size = size
    }

    override func execute(_ connection: RTMPConnection, type: RTMPChunkType) {
        connection.socket.chunkSizeC = Int(size)
    }
}

// MARK: -
/**
 5.4.2. Abort Message (2)
 */
final class RTMPAbortMessge: RTMPMessage {
    var chunkStreamId: UInt32 = 0

    override var payload: Data {
        get {
            guard super.payload.isEmpty else {
                return super.payload
            }
            super.payload = chunkStreamId.bigEndian.data
            return super.payload
        }
        set {
            if super.payload == newValue {
                return
            }
            chunkStreamId = UInt32(data: newValue).bigEndian
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
    var sequence: UInt32 = 0

    override var payload: Data {
        get {
            guard super.payload.isEmpty else {
                return super.payload
            }
            super.payload = sequence.bigEndian.data
            return super.payload
        }
        set {
            if super.payload == newValue {
                return
            }
            sequence = UInt32(data: newValue).bigEndian
            super.payload = newValue
        }
    }

    init() {
        super.init(type: .ack)
    }

    init(_ sequence: UInt32) {
        super.init(type: .ack)
        self.sequence = sequence
    }
}

// MARK: -
/**
 5.4.4. Window Acknowledgement Size (5)
 */
final class RTMPWindowAcknowledgementSizeMessage: RTMPMessage {
    var size: UInt32 = 0

    init() {
        super.init(type: .windowAck)
    }

    init(_ size: UInt32) {
        super.init(type: .windowAck)
        self.size = size
    }

    override var payload: Data {
        get {
            guard super.payload.isEmpty else {
                return super.payload
            }
            super.payload = size.bigEndian.data
            return super.payload
        }
        set {
            if super.payload == newValue {
                return
            }
            size = UInt32(data: newValue).bigEndian
            super.payload = newValue
        }
    }

    override func execute(_ connection: RTMPConnection, type: RTMPChunkType) {
        connection.windowSizeC = Int64(size)
        connection.windowSizeS = Int64(size)
    }
}

// MARK: -
/**
 5.4.5. Set Peer Bandwidth (6)
 */
final class RTMPSetPeerBandwidthMessage: RTMPMessage {

    enum Limit: UInt8 {
        case hard = 0x00
        case soft = 0x01
        case dynamic = 0x02
        case unknown = 0xFF
    }

    var size: UInt32 = 0
    var limit: Limit = .hard

    init() {
        super.init(type: .bandwidth)
    }

    override var payload: Data {
        get {
            guard super.payload.isEmpty else {
                return super.payload
            }
            var payload = Data()
            payload.append(size.bigEndian.data)
            payload.append(limit.rawValue)
            super.payload = payload
            return super.payload
        }
        set {
            if super.payload == newValue {
                return
            }
            size = UInt32(data: newValue[0..<4]).bigEndian
            limit = Limit(rawValue: newValue[4]) ?? .unknown
            super.payload = newValue
        }
    }

    override func execute(_ connection: RTMPConnection, type: RTMPChunkType) {
        connection.bandWidth = size
    }
}

// MARK: -
/**
 7.1.1. Command Message (20, 17)
 */
final class RTMPCommandMessage: RTMPMessage {

    let objectEncoding: UInt8
    var commandName: String = ""
    var transactionId: Int = 0
    var commandObject: ASObject?
    var arguments: [Any?] = []

    override var payload: Data {
        get {
            guard super.payload.isEmpty else {
                return super.payload
            }
            if type == .amf3Command {
                serializer.writeUInt8(0)
            }
            serializer
                .serialize(commandName)
                .serialize(transactionId)
                .serialize(commandObject)
            for i in arguments {
                serializer.serialize(i)
            }
            super.payload = serializer.data
            serializer.clear()
            return super.payload
        }
        set {
            if length == newValue.count {
                serializer.writeBytes(newValue)
                serializer.position = 0
                do {
                    if type == .amf3Command {
                        serializer.position = 1
                    }
                    commandName = try serializer.deserialize()
                    transactionId = try serializer.deserialize()
                    commandObject = try serializer.deserialize()
                    arguments.removeAll()
                    if 0 < serializer.bytesAvailable {
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

    private var serializer: AMFSerializer = AMF0Serializer()

    init(objectEncoding: UInt8) {
        self.objectEncoding = objectEncoding
        super.init(type: objectEncoding == 0x00 ? .amf0Command : .amf3Command)
    }

    init(streamId: UInt32, transactionId: Int, objectEncoding: UInt8, commandName: String, commandObject: ASObject?, arguments: [Any?]) {
        self.transactionId = transactionId
        self.objectEncoding = objectEncoding
        self.commandName = commandName
        self.commandObject = commandObject
        self.arguments = arguments
        super.init(type: objectEncoding == 0x00 ? .amf0Command : .amf3Command)
        self.streamId = streamId
    }

    override func execute(_ connection: RTMPConnection, type: RTMPChunkType) {

        guard let responder: Responder = connection.operations.removeValue(forKey: transactionId) else {
            switch commandName {
            case "close":
                connection.close(isDisconnected: true)
            default:
                connection.dispatch(Event.RTMP_STATUS, bubbles: false, data: arguments.first)
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

    let objectEncoding: UInt8
    var handlerName: String = ""
    var arguments: [Any?] = []

    private var serializer: AMFSerializer = AMF0Serializer()

    override var payload: Data {
        get {
            guard super.payload.isEmpty else {
                return super.payload
            }

            if type == .amf3Data {
                serializer.writeUInt8(0)
            }
            serializer.serialize(handlerName)
            for arg in arguments {
                serializer.serialize(arg)
            }
            super.payload = serializer.data
            serializer.clear()

            return super.payload
        }
        set {
            guard super.payload != newValue else {
                return
            }

            if length == newValue.count {
                serializer.writeBytes(newValue)
                serializer.position = 0
                if type == .amf3Data {
                    serializer.position = 1
                }
                do {
                    handlerName = try serializer.deserialize()
                    while 0 < serializer.bytesAvailable {
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

    init(objectEncoding: UInt8) {
        self.objectEncoding = objectEncoding
        super.init(type: objectEncoding == 0x00 ? .amf0Data : .amf3Data)
    }

    init(streamId: UInt32, objectEncoding: UInt8, handlerName: String, arguments: [Any?] = []) {
        self.objectEncoding = objectEncoding
        self.handlerName = handlerName
        self.arguments = arguments
        super.init(type: objectEncoding == 0x00 ? .amf0Data : .amf3Data)
        self.streamId = streamId
    }

    override func execute(_ connection: RTMPConnection, type: RTMPChunkType) {
        guard let stream: RTMPStream = connection.streams[streamId] else {
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

    let objectEncoding: UInt8
    var sharedObjectName: String = ""
    var currentVersion: UInt32 = 0
    var flags = Data(count: 8)
    var events: [RTMPSharedObjectEvent] = []

    override var payload: Data {
        get {
            guard super.payload.isEmpty else {
                return super.payload
            }

            if type == .amf3Shared {
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
            super.payload = serializer.data
            serializer.clear()

            return super.payload
        }
        set {
            if super.payload == newValue {
                return
            }

            if length == newValue.count {
                serializer.writeBytes(newValue)
                serializer.position = 0
                if type == .amf3Shared {
                    serializer.position = 1
                }
                do {
                    sharedObjectName = try serializer.readUTF8()
                    currentVersion = try serializer.readUInt32()
                    flags = try serializer.readBytes(8)
                    while 0 < serializer.bytesAvailable {
                        if let event: RTMPSharedObjectEvent = try RTMPSharedObjectEvent(serializer: &serializer) {
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

    private var serializer: AMFSerializer = AMF0Serializer()

    init(objectEncoding: UInt8) {
        self.objectEncoding = objectEncoding
        super.init(type: objectEncoding == 0x00 ? .amf0Shared : .amf3Shared)
    }

    init(timestamp: UInt32, objectEncoding: UInt8, sharedObjectName: String, currentVersion: UInt32, flags: Data, events: [RTMPSharedObjectEvent]) {
        self.objectEncoding = objectEncoding
        self.sharedObjectName = sharedObjectName
        self.currentVersion = currentVersion
        self.flags = flags
        self.events = events
        super.init(type: objectEncoding == 0x00 ? .amf0Shared : .amf3Shared)
        self.timestamp = timestamp
    }

    override func execute(_ connection: RTMPConnection, type: RTMPChunkType) {
        let persistence: Bool = flags[0] == 0x01
        RTMPSharedObject.getRemote(withName: sharedObjectName, remotePath: connection.uri!.absoluteWithoutQueryString, persistence: persistence).on(message: self)
    }
}

// MARK: -
/**
 7.1.5. Audio Message (9)
 */
final class RTMPAudioMessage: RTMPMessage {
    private(set) var codec: FLVAudioCodec = .unknown
    private(set) var soundRate: FLVSoundRate = .kHz44
    private(set) var soundSize: FLVSoundSize = .snd8bit
    private(set) var soundType: FLVSoundType = .stereo

    override var payload: Data {
        get {
            return super.payload
        }
        set {
            if super.payload == newValue {
                return
            }

            super.payload = newValue

            if length == newValue.count && !newValue.isEmpty {
                guard let codec = FLVAudioCodec(rawValue: newValue[0] >> 4),
                    let soundRate = FLVSoundRate(rawValue: (newValue[0] & 0b00001100) >> 2),
                    let soundSize = FLVSoundSize(rawValue: (newValue[0] & 0b00000010) >> 1),
                    let soundType = FLVSoundType(rawValue: (newValue[0] & 0b00000001)) else {
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

    init(streamId: UInt32, timestamp: UInt32, payload: Data) {
        super.init(type: .audio)
        self.streamId = streamId
        self.timestamp = timestamp
        self.payload = payload
    }

    override func execute(_ connection: RTMPConnection, type: RTMPChunkType) {
        guard let stream: RTMPStream = connection.streams[streamId] else {
            return
        }
        OSAtomicAdd64(Int64(payload.count), &stream.info.byteCount)
        guard codec.isSupported else {
            return
        }
        switch type {
        case .zero:
            stream.audioTimestamp = Double(timestamp)
        default:
            stream.audioTimestamp += Double(timestamp)
        }
        switch FLVAACPacketType(rawValue: payload[1]) {
        case .seq?:
            let config = AudioSpecificConfig(bytes: [UInt8](payload[codec.headerSize..<payload.count]))
            stream.mixer.audioIO.encoder.destination = .PCM
            stream.mixer.audioIO.encoder.inSourceFormat = config?.audioStreamBasicDescription()
        case .raw?:
            let computedSoundData = payload.advanced(by: codec.headerSize)
            var data: Data = computedSoundData
            data.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) -> Void in
                stream.mixer.audioIO.encoder.encodeBytes(bytes, count: computedSoundData.count, presentationTimeStamp: CMTime(seconds: stream.audioTimestamp / 1000, preferredTimescale: 1000))
            }
        case .none:
            break
        }
    }
}

// MARK: -
/**
 7.1.5. Video Message (9)
 */
final class RTMPVideoMessage: RTMPMessage {
    private(set) var codec: FLVVideoCodec = .unknown
    private(set) var status: OSStatus = noErr

    init() {
        super.init(type: .video)
    }

    init(streamId: UInt32, timestamp: UInt32, payload: Data) {
        super.init(type: .video)
        self.streamId = streamId
        self.timestamp = timestamp
        self.payload = payload
    }

    override func execute(_ connection: RTMPConnection, type: RTMPChunkType) {
        guard let stream: RTMPStream = connection.streams[streamId] else {
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
            enqueueSampleBuffer(stream, type: type)
        default:
            break
        }
    }

    func enqueueSampleBuffer(_ stream: RTMPStream, type: RTMPChunkType) {
        let compositionTimeoffset = Int32(data: [0] + payload[2..<5]).bigEndian

        if timestamp == 0 && compositionTimeoffset != 0 {
            timestamp = UInt32(Double(compositionTimeoffset) - stream.videoTimestamp)
        }

        switch type {
        case .zero:
            stream.videoTimestamp = Double(timestamp)
        default:
            stream.videoTimestamp += Double(timestamp)
        }

        var timing = CMSampleTimingInfo(
            duration: CMTimeMake(value: Int64(timestamp), timescale: 1000),
            presentationTimeStamp: CMTimeMake(value: Int64(stream.videoTimestamp), timescale: 1000),
            decodeTimeStamp: CMTime.invalid
        )

        var data: Data = payload.advanced(by: FLVTagType.video.headerSize)
        var localData = data
        localData.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) -> Void in
            var blockBuffer: CMBlockBuffer?
            guard CMBlockBufferCreateWithMemoryBlock(
                allocator: kCFAllocatorDefault, memoryBlock: bytes, blockLength: data.count, blockAllocator: kCFAllocatorNull, customBlockSource: nil, offsetToData: 0, dataLength: data.count, flags: 0, blockBufferOut: &blockBuffer) == noErr else {
                return
            }
            var sampleBuffer: CMSampleBuffer?
            var sampleSizes: [Int] = [data.count]
            guard CMSampleBufferCreate(
                allocator: kCFAllocatorDefault, dataBuffer: blockBuffer!, dataReady: true, makeDataReadyCallback: nil, refcon: nil, formatDescription: stream.mixer.videoIO.formatDescription, sampleCount: 1, sampleTimingEntryCount: 1, sampleTimingArray: &timing, sampleSizeEntryCount: 1, sampleSizeArray: &sampleSizes, sampleBufferOut: &sampleBuffer) == noErr else {
                return
            }
            status = stream.mixer.videoIO.decoder.decodeSampleBuffer(sampleBuffer!)
            if stream.mixer.videoIO.queue.locked.value {
                stream.mixer.videoIO.queue.locked.mutate { value in
                    value = timestamp != 0
                }
            }
        }
    }

    func createFormatDescription(_ stream: RTMPStream) -> OSStatus {
        var config = AVCConfigurationRecord()
        config.data = payload.subdata(in: FLVTagType.video.headerSize..<payload.count)
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
        case streamEof = 0x01
        case streamDry = 0x02
        case setBuffer = 0x03
        case recorded = 0x04
        case ping = 0x06
        case pong = 0x07
        case bufferEmpty = 0x1F
        case bufferFull = 0x20
        case unknown = 0xFF

        var bytes: [UInt8] {
            return [0x00, rawValue]
        }
    }

    var event: Event = .unknown
    var value: Int32 = 0

    override var payload: Data {
        get {
            guard super.payload.isEmpty else {
                return super.payload
            }
            super.payload.removeAll()
            super.payload += event.bytes
            super.payload += value.bigEndian.data
            return super.payload
        }
        set {
            if super.payload == newValue {
                return
            }
            if length == newValue.count {
                if let event = Event(rawValue: newValue[1]) {
                    self.event = event
                }
                value = Int32(data: newValue[2..<newValue.count]).bigEndian
            }
            super.payload = newValue
        }
    }

    init() {
        super.init(type: .user)
    }

    init(event: Event, value: Int32) {
        super.init(type: .user)
        self.event = event
        self.value = value
    }

    override func execute(_ connection: RTMPConnection, type: RTMPChunkType) {
        switch event {
        case .ping:
            connection.socket.doOutput(chunk: RTMPChunk(
                type: .zero,
                streamId: RTMPChunk.StreamID.control.rawValue,
                message: RTMPUserControlMessage(event: .pong, value: value)
            ), locked: nil)
        case .bufferEmpty, .bufferFull:
            connection.streams[UInt32(value)]?.dispatch("rtmpStatus", bubbles: false, data: [
                "level": "status",
                "description": ""
            ])
        default:
            break
        }
    }
}
