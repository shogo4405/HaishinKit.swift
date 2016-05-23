import Foundation
import AVFoundation

class RTMPMessage {

    enum Type: UInt8 {
        case ChunkSize   = 1
        case Abort       = 2
        case Ack         = 3
        case User        = 4
        case WindowAck   = 5
        case Bandwidth   = 6
        case Audio       = 8
        case Video       = 9
        case AMF3Data    = 15
        case AMF3Shared  = 16
        case AMF3Command = 17
        case AMF0Data    = 18
        case AMF0Shared  = 19
        case AMF0Command = 20
        case Aggregate   = 22
        case Unknown     = 255
    }

    static func create(value:UInt8) -> RTMPMessage? {
        switch value {
        case Type.ChunkSize.rawValue:
            return RTMPSetChunkSizeMessage()
        case Type.Abort.rawValue:
            return RTMPAbortMessge()
        case Type.Ack.rawValue:
            return RTMPAcknowledgementMessage();
        case Type.User.rawValue:
            return RTMPUserControlMessage()
        case Type.WindowAck.rawValue:
            return RTMPWindowAcknowledgementSizeMessage()
        case Type.Bandwidth.rawValue:
            return RTMPSetPeerBandwidthMessage()
        case Type.Audio.rawValue:
            return RTMPAudioMessage()
        case Type.Video.rawValue:
            return RTMPVideoMessage()
        /*
        case Type.AMF3Data.rawValue:
            return RTMPDataMessage(objectEncoding: 0x03)
        case Type.AMF3Shared.rawValue:
            return RTMPSharedObjectMessage(objectEncoding: 0x03)
        case Type.AMF3Command.rawValue:
            return RTMPCommandMessage(objectEncoding: 0x03)
        */
        case Type.AMF0Data.rawValue:
            return RTMPDataMessage(objectEncoding: 0x00)
        case Type.AMF0Shared.rawValue:
            return RTMPSharedObjectMessage(objectEncoding: 0x00)
        case Type.AMF0Command.rawValue:
            return RTMPCommandMessage(objectEncoding: 0x00)
        case Type.Aggregate.rawValue:
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

    func execute(connection:RTMPConnection) {
    }
}

// MARK: CustomStringConvertible
extension RTMPMessage: CustomStringConvertible {
    var description:String {
        return Mirror(reflecting: self).description
    }
}

// MARK: -
/**
 5.4.1. Set Chunk Size (1)
 */
final class RTMPSetChunkSizeMessage: RTMPMessage {

    var size:UInt32 = 0 {
        didSet {
            super.payload.removeAll(keepCapacity: false)
        }
    }

    init() {
        super.init(type: .ChunkSize)
    }

    init(size:UInt32) {
        super.init(type: .ChunkSize)
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

    override func execute(connection:RTMPConnection) {
        connection.socket.chunkSizeC = Int(size)
    }
}

// MARK: -
/**
 5.4.2. Abort Message (2)
 */
final class RTMPAbortMessge: RTMPMessage {
    var chunkStreamId:UInt32 = 0 {
        didSet {
            super.payload.removeAll(keepCapacity: false)
        }
    }

    init() {
        super.init(type: .Abort)
    }

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
}

// MARK: -
/**
 5.4.3. Acknowledgement (3)
 */
final class RTMPAcknowledgementMessage: RTMPMessage {
    init() {
        super.init(type: .Ack)
    }

    var sequence:UInt32 = 0 {
        didSet {
            super.payload.removeAll(keepCapacity: false)
        }
    }
    
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
}

// MARK: -
/**
 5.4.4. Window Acknowledgement Size (5)
 */
final class RTMPWindowAcknowledgementSizeMessage: RTMPMessage {
    var size:UInt32 = 0 {
        didSet {
            super.payload.removeAll(keepCapacity: false)
        }
    }

    init() {
        super.init(type: .WindowAck)
    }

    init(size:UInt32) {
        super.init(type: .WindowAck)
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

    override func execute(connection: RTMPConnection) {
        connection.socket.doOutput(chunk: RTMPChunk(
            type: .Zero,
            streamId: RTMPChunk.control,
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
        case Hard    = 0x00
        case Soft    = 0x01
        case Dynamic = 0x10
        case Unknown = 0xFF
    }

    var size:UInt32 = 0 {
        didSet {
            super.payload.removeAll(keepCapacity: false)
        }
    }

    var limit:Limit = .Hard {
        didSet {
            super.payload.removeAll(keepCapacity: false)
        }
    }

    init() {
        super.init(type: .Bandwidth)
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

    override func execute(connection: RTMPConnection) {
        connection.bandWidth = size
    }
}

// MARK: -
/**
 7.1.1. Command Message (20, 17)
 */
final class RTMPCommandMessage: RTMPMessage {

    let objectEncoding:UInt8

    var commandName:String = "" {
        didSet {
            super.payload.removeAll(keepCapacity: false)
        }
    }

    var transactionId:Int = 0 {
        didSet {
            super.payload.removeAll(keepCapacity: false)
        }
    }

    var commandObject:ASObject? = nil {
        didSet {
            super.payload.removeAll(keepCapacity: false)
        }
    }

    var arguments:[Any?] = [] {
        didSet {
            super.payload.removeAll(keepCapacity: false)
        }
    }

    override var payload:[UInt8] {
        get {
            guard super.payload.isEmpty else {
                return super.payload
            }
            serializer.serialize(commandName)
            serializer.serialize(transactionId)
            serializer.serialize(commandObject)
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
                    commandName = try serializer.deserialize()
                    transactionId = try serializer.deserialize()
                    commandObject = try serializer.deserialize()
                    arguments.removeAll()
                    if (0 < serializer.bytesAvailable) {
                        arguments.append(try serializer.deserialize())
                    }
                } catch {
                    logger.error("\(serializer)")
                }
                serializer.clear()
            }
            super.payload = newValue
        }
    }

    private var serializer:AMFSerializer

    init(objectEncoding:UInt8) {
        self.objectEncoding = objectEncoding
        self.serializer = objectEncoding == 0x00 ? AMF0Serializer() : AMF3Serializer()
        super.init(type: objectEncoding == 0x00 ? .AMF0Command : .AMF3Command)
    }

    init(streamId:UInt32, transactionId:Int, objectEncoding:UInt8, commandName:String, commandObject: ASObject?, arguments:[Any?]) {
        self.transactionId = transactionId
        self.objectEncoding = objectEncoding
        self.commandName = commandName
        self.commandObject = commandObject
        self.arguments = arguments
        self.serializer = objectEncoding == 0x00 ? AMF0Serializer() : AMF3Serializer()
        super.init(type: objectEncoding == 0x00 ? .AMF0Command : .AMF3Command)
        self.streamId = streamId
    }

    override func execute(connection: RTMPConnection) {

        guard let responder:Responder = connection.operations.removeValueForKey(transactionId) else {
            switch commandName {
            case "close":
                connection.close()
            default:
                connection.dispatchEventWith(Event.RTMP_STATUS, bubbles: false, data: arguments.isEmpty ? nil : arguments[0])
            }
            return
        }

        switch commandName {
        case "_result":
            responder.onResult(arguments)
        case "_error":
            responder.onStatus(arguments)
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

    var handlerName:String = "" {
        didSet {
            payload.removeAll(keepCapacity: false)
        }
    }

    var arguments:[Any?] = [] {
        didSet {
            payload.removeAll(keepCapacity: false)
        }
    }

    private var serializer:AMFSerializer

    override var payload:[UInt8] {
        get {
            guard super.payload.isEmpty else {
                return super.payload
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
                do {
                    handlerName = try serializer.deserialize()
                    while (0 < serializer.bytesAvailable) {
                        arguments.append(try serializer.deserialize())
                    }
                } catch {
                    logger.error("\(serializer)")
                }
                serializer.clear()
            }

            super.payload = newValue
        }
    }

    init(objectEncoding:UInt8) {
        self.objectEncoding = objectEncoding
        self.serializer = objectEncoding == 0x00 ? AMF0Serializer() : AMF3Serializer()
        super.init(type: objectEncoding == 0x00 ? .AMF0Data : .AMF3Data)
    }

    init(streamId:UInt32, objectEncoding:UInt8, handlerName:String, arguments:[Any?]) {
        self.objectEncoding = objectEncoding
        self.handlerName = handlerName
        self.arguments = arguments
        self.serializer = objectEncoding == 0x00 ? AMF0Serializer() : AMF3Serializer()
        super.init(type: objectEncoding == 0x00 ? .AMF0Data : .AMF3Data)
        self.streamId = streamId
    }

    convenience init(streamId:UInt32, objectEncoding:UInt8, handlerName:String) {
        self.init(streamId: streamId, objectEncoding: objectEncoding, handlerName: handlerName, arguments: [])
    }

    override func execute(connection: RTMPConnection) {
        guard let stream:RTMPStream = connection.streams[streamId] else {
            return
        }
        stream.recorder.onMessage(self)
    }
}

// MARK: -
/**
 7.1.3. Shared Object Message (19, 16)
 */
final class RTMPSharedObjectMessage: RTMPMessage {

    let objectEncoding:UInt8

    var sharedObjectName:String = "" {
        didSet {
            super.payload.removeAll(keepCapacity: false)
        }
    }

    var currentVersion:UInt32 = 0 {
        didSet {
            super.payload.removeAll(keepCapacity: false)
        }
    }

    var flags:[UInt8] = [UInt8](count: 8, repeatedValue: 0x00) {
        didSet {
            super.payload.removeAll(keepCapacity: false)
        }
    }

    var events:[RTMPSharedObjectEvent] = [] {
        didSet {
            super.payload.removeAll(keepCapacity: false)
        }
    }

    override var payload:[UInt8] {
        get {
            guard super.payload.isEmpty else {
                return super.payload
            }

            do {
                try serializer.writeUTF8(sharedObjectName)
                serializer.writeUInt32(currentVersion)
                serializer.writeBytes(flags)
                for event in events {
                    try event.serialize(&serializer)
                }
                super.payload = serializer.bytes
                serializer.clear()
            } catch {
                logger.error("\(serializer)")
            }

            return super.payload
        }
        set {
            if (super.payload == newValue) {
                return
            }

            if (length == newValue.count) {
                serializer.writeBytes(newValue)
                serializer.position = 0
                do {
                    sharedObjectName = try serializer.readUTF8()
                    currentVersion = try serializer.readUInt32()
                    flags = try serializer.readBytes(8)
                    events.removeAll(keepCapacity: false)
                    while (0 < serializer.bytesAvailable) {
                        if let event:RTMPSharedObjectEvent = try RTMPSharedObjectEvent(serializer: serializer) {
                            events.append(event)
                        }
                    }
                } catch {
                    logger.error("\(serializer)")
                }
                serializer.clear()
            }

            super.payload = newValue
        }
    }

    private var serializer:AMFSerializer

    init(objectEncoding:UInt8) {
        self.objectEncoding = objectEncoding
        self.serializer = objectEncoding == 0x00 ? AMF0Serializer() : AMF3Serializer()
        super.init(type: objectEncoding == 0x00 ? .AMF0Shared : .AMF3Shared)
    }

    init(timestamp:UInt32, objectEncoding:UInt8, sharedObjectName:String, currentVersion:UInt32, flags:[UInt8], events:[RTMPSharedObjectEvent]) {
        self.objectEncoding = objectEncoding
        self.sharedObjectName = sharedObjectName
        self.currentVersion = currentVersion
        self.flags = flags
        self.events = events
        self.serializer = objectEncoding == 0x00 ? AMF0Serializer() : AMF3Serializer()
        super.init(type: objectEncoding == 0x00 ? .AMF0Shared : .AMF3Shared)
        self.timestamp = timestamp
    }

    override func execute(connection:RTMPConnection) {
        let persistence:Bool = flags[0] == 0x01
        RTMPSharedObject.getRemote(sharedObjectName, remotePath: connection.uri!.absoluteWithoutQueryString, persistence: persistence).onMessage(self)
    }
}

// MARK: -
/**
 7.1.5. Audio Message (9)
 */
final class RTMPAudioMessage: RTMPMessage {
    var config:AudioSpecificConfig?

    private(set) var codec:FLVAudioCodec = .Unknown
    private(set) var soundRate:FLVSoundRate = .KHz44
    private(set) var soundSize:FLVSoundSize = .Snd8bit
    private(set) var soundType:FLVSoundType = .Stereo

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
                    soundRate:FLVSoundRate = FLVSoundRate(rawValue: (newValue[0] & 0b00001100) >> 2),
                    soundSize:FLVSoundSize = FLVSoundSize(rawValue: (newValue[0] & 0b00000010) >> 1),
                    soundType:FLVSoundType = FLVSoundType(rawValue: (newValue[0] & 0b00000001)) else {
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
        super.init(type: .Audio)
    }

    init(streamId: UInt32, timestamp: UInt32, buffer:NSData) {
        super.init(type: .Audio)
        self.streamId = streamId
        self.timestamp = timestamp
        var payload:[UInt8] = [UInt8](count: buffer.length, repeatedValue: 0x00)
        buffer.getBytes(&payload, length: payload.count)
        self.payload = payload
    }

    override func execute(connection:RTMPConnection) {
        guard let stream:RTMPStream = connection.streams[streamId] else {
            return
        }
        stream.audioPlayback.onMessage(self)
        stream.recorder.onMessage(self)
    }

    func createAudioSpecificConfig() -> AudioSpecificConfig? {
        if (payload.isEmpty) {
            return nil
        }

        guard codec == FLVAudioCodec.AAC else {
            return nil
        }

        if (payload[1] == FLVAACPacketType.Seq.rawValue) {
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
    private(set) var codec:FLVVideoCodec = .Unknown

    init() {
        super.init(type: .Video)
    }

    init(streamId: UInt32, timestamp: UInt32, buffer:NSData) {
        super.init(type: .Video)
        self.streamId = streamId
        self.timestamp = timestamp
        payload = [UInt8](count: buffer.length, repeatedValue: 0x00)
        buffer.getBytes(&payload, length: payload.count)
    }

    override func execute(connection:RTMPConnection) {
        guard let stream:RTMPStream = connection.streams[streamId] else {
            return
        }
        stream.recorder.onMessage(self)
        guard FLVTag.TagType.Video.headerSize < payload.count else {
            return
        }
        switch payload[1] {
        case FLVAVCPacketType.Seq.rawValue:
            createFormatDescription(stream)
        case FLVAVCPacketType.Nal.rawValue:
            enqueueSampleBuffer(stream)
        default:
            break
        }
    }

    func enqueueSampleBuffer(stream: RTMPStream) {
        stream.videoTimestamp += Double(timestamp)
        let compositionTimeoffset:Int32 = Int32(bytes: [0] + payload[2..<5]).bigEndian
        var timing:CMSampleTimingInfo = CMSampleTimingInfo(
            duration: CMTimeMake(Int64(timestamp), 1000),
            presentationTimeStamp: CMTimeMake(Int64(stream.videoTimestamp) + Int64(compositionTimeoffset), 1000),
            decodeTimeStamp: kCMTimeInvalid
        )
        stream.mixer.videoIO.enqueSampleBuffer(
            Array(payload[FLVTag.TagType.Video.headerSize..<payload.count]),
            timing: &timing
        )
    }

    func createFormatDescription(stream: RTMPStream) -> OSStatus{
        var config:AVCConfigurationRecord = AVCConfigurationRecord()
        config.bytes = Array(payload[FLVTag.TagType.Video.headerSize..<payload.count])
        return config.createFormatDescription(&stream.mixer.videoIO.formatDescription)
    }
}

// MARK: -
/**
 7.1.6. Aggregate Message (22)
 */
final class RTMPAggregateMessage: RTMPMessage {
    init() {
        super.init(type: .Aggregate)
    }
}

// MARK: -
/**
 7.1.7. User Control Message Events
 */
final class RTMPUserControlMessage: RTMPMessage {

    enum Event: UInt8 {
        case StreamBegin = 0x00
        case StreamEof   = 0x01
        case StreamDry   = 0x02
        case SetBuffer   = 0x03
        case Recorded    = 0x04
        case Ping        = 0x06
        case Pong        = 0x07
        case BufferEmpty = 0x1F
        case BufferFull  = 0x20
        case Unknown     = 0xFF

        var bytes:[UInt8] {
            return [0x00, rawValue]
        }
    }

    var event:Event = .Unknown {
        didSet {
            super.payload.removeAll(keepCapacity: false)
        }
    }

    var value:Int32 = 0 {
        didSet {
            super.payload.removeAll(keepCapacity: false)
        }
    }

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
        super.init(type: .User)
    }

    init(event:Event, value:Int32) {
        super.init(type: .User)
        self.event = event
        self.value = value
    }

    override func execute(connection: RTMPConnection) {
        switch event {
        case .Ping:
            connection.socket.doOutput(chunk: RTMPChunk(
                type: .Zero,
                streamId: RTMPChunk.control,
                message: RTMPUserControlMessage(event: .Pong, value: value)
            ))
        case .BufferEmpty, .BufferFull:
            connection.streams[UInt32(value)]?.dispatchEventWith("rtmpStatus", bubbles: false, data: [
                "level": "status",
                "code": description,
                "description": ""
            ])
        default:
            break
        }
    }
}
