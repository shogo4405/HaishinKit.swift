import Foundation
import AVFoundation

class RTMPMessage: NSObject {

    enum Type:UInt8 {
        case ChunkSize = 1
        case Abort = 2
        case Ack = 3
        case User = 4
        case WindowAck = 5
        case Bandwidth = 6
        case Audio = 8
        case Video = 9
        case AMF3Data = 15
        case AMF3Shared = 16
        case AMF3Command = 17
        case AMF0Data = 18
        case AMF0Shared = 19
        case AMF0Command = 20
        case Aggregate = 22
        case Unknown = 255
    }

    static func create(type:UInt8) -> RTMPMessage {
        switch type {
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
            return RTMPMessage(type: Type(rawValue: type)!)
        }
    }

    private var _type:Type = .Unknown
    var type:Type {
        return _type
    }

    var length:Int = 0
    var streamId:UInt32 = 0
    var timestamp:UInt32 = 0
    var payload:[UInt8] = []

    override var description:String {
        let className:NSString = NSStringFromClass(self.dynamicType).componentsSeparatedByString(".").last! as String
        var description:String = "\(className){"
        description += "type:\(type.rawValue),"
        description += "length:\(length),"
        description += "streamId:\(streamId),"
        description += "timestamp:\(timestamp),"
        description += "payload:\(payload.count)"
        description += "}"
        return description
    }

    override init() {
        super.init()
    }

    init(type:Type) {
        _type = type
    }

    func execute(connection:RTMPConnection) {
    }
}

/**
 * @see 5.4.1. Set Chunk Size (1)
 */
final class RTMPSetChunkSizeMessage:RTMPMessage {
    
    override var type:Type {
        return .ChunkSize
    }
    
    var size:UInt32 = 0 {
        didSet {
            super.payload.removeAll(keepCapacity: false)
        }
    }

    override init() {
        super.init()
    }

    init (size:UInt32) {
        super.init()
        self.size = size
    }
    
    override var payload:[UInt8] {
        get {
            if (!super.payload.isEmpty) {
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

/**
 * 5.4.2. Abort Message (2)
 */
final class RTMPAbortMessge: RTMPMessage {
    override var type:Type {
        return .Abort
    }

    var chunkStreamId:UInt32 = 0 {
        didSet {
            super.payload.removeAll(keepCapacity: false)
        }
    }

    override var payload:[UInt8] {
        get {
            if (!super.payload.isEmpty) {
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

/**
 * 5.4.3. Acknowledgement (3)
 */
final class RTMPAcknowledgementMessage: RTMPMessage {
    override var type:Type {
        return .Ack
    }

    var sequence:UInt32 = 0 {
        didSet {
            super.payload.removeAll(keepCapacity: false)
        }
    }
    
    override var payload:[UInt8] {
        get {
            if (!super.payload.isEmpty) {
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

/**
 * 5.4.4. Window Acknowledgement Size (5)
 */
final class RTMPWindowAcknowledgementSizeMessage:RTMPMessage {
    
    override var type:Type {
        return .WindowAck
    }
    
    var size:UInt32 = 0 {
        didSet {
            super.payload.removeAll(keepCapacity: false)
        }
    }
    
    override var payload:[UInt8] {
        get {
            if (!super.payload.isEmpty) {
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
}

/**
 * @see 5.4.5. Set Peer Bandwidth (6)
 */
final class RTMPSetPeerBandwidthMessage:RTMPMessage {
    
    enum Limit:UInt8 {
        case Hard = 0x00
        case Soft = 0x01
        case Dynamic = 0x10
        case Unknown = 0xFF
    }
    
    override var type:Type {
        return .Bandwidth
    }
    
    var size:UInt32 = 0 {
        didSet {
            super.payload.removeAll(keepCapacity: false)
        }
    }
    
    var limit:Limit = Limit.Hard {
        didSet {
            super.payload.removeAll(keepCapacity: false)
        }
    }
    
    override var payload:[UInt8] {
        get {
            if (!super.payload.isEmpty) {
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

/**
 * @see 7.1.1. Command Message (20, 17)
 */
final class RTMPCommandMessage: RTMPMessage {

    var objectEncoding:UInt8 = RTMPConnection.defaultObjectEncoding {
        didSet {
            self.serializer = objectEncoding == 0x00 ? AMF0Serializer() : AMF3Serializer()
        }
    }

    override var type:Type {
        return objectEncoding == 0x00 ? .AMF0Command : .AMF3Command
    }
    
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
            if (!super.payload.isEmpty) {
                return super.payload
            }
            super.payload += serializer.serialize(commandName)
            super.payload += serializer.serialize(transactionId)
            super.payload += serializer.serialize(commandObject)
            for i in arguments {
                super.payload += serializer.serialize(i)
            }
            return super.payload
        }
        set {
            if (super.payload == newValue) {
                return
            }
            if (length == newValue.count) {
                var position:Int = 0
                var bytes:[UInt8] = newValue
                commandName = serializer.deserialize(&bytes, &position)
                transactionId = serializer.deserialize(&bytes, &position)
                commandObject = serializer.deserialize(&bytes, &position)
                arguments.removeAll()
                if (position < newValue.count) {
                    arguments.append(serializer.deserialize(&bytes, &position))
                }
            }
            super.payload = newValue
        }
    }
    
    override var description: String {
        var description:String = "RTMPCommandMessage{"
        description += "type:\(type),"
        description += "length:\(length),"
        description += "streamId:\(streamId),"
        description += "timestamp:\(timestamp),"
        description += "commandName:\(commandName),"
        description += "transactionId:\(transactionId),"
        description += "commandObject:\(commandObject),"
        description += "arguments:\(arguments)"
        description += "}"
        return description
    }

    private var serializer:AMFSerializer = RTMPConnection.defaultObjectEncoding == 0x00 ? AMF0Serializer() : AMF3Serializer()

    override init () {
        super.init()
    }

    init(objectEncoding:UInt8) {
        super.init()
        self.objectEncoding = objectEncoding
        self.serializer = objectEncoding == 0x00 ? AMF0Serializer() : AMF3Serializer()
    }

    init(streamId:UInt32, transactionId:Int, objectEncoding:UInt8, commandName:String, commandObject: ASObject?, arguments:[Any?]) {
        super.init()
        self.streamId = streamId
        self.transactionId = transactionId
        self.objectEncoding = objectEncoding
        self.commandName = commandName
        self.commandObject = commandObject
        self.arguments = arguments
        self.serializer = objectEncoding == 0x00 ? AMF0Serializer() : AMF3Serializer()
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

/**
 * @see 7.1.2. Data Message (18, 15)
 */
final class RTMPDataMessage:RTMPMessage {

    var objectEncoding:UInt8 = RTMPConnection.defaultObjectEncoding {
        didSet {
            self.serializer = objectEncoding == 0x00 ? AMF0Serializer() : AMF3Serializer()
        }
    }

    override var type:Type {
        return objectEncoding == 0x00 ? .AMF0Data : .AMF3Data
    }

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

    private var serializer:AMFSerializer = RTMPConnection.defaultObjectEncoding == 0x00 ? AMF0Serializer() : AMF3Serializer()

    override var description: String {
        var description:String = "RTMPDataMessage{"
        description += "type:\(type.rawValue),"
        description += "length:\(length),"
        description += "streamId:\(streamId),"
        description += "timestamp:\(timestamp),"
        description += "handlerName:\(handlerName),"
        description += "arguments:\(arguments)"
        description += "}"
        return description
    }

    override var payload:[UInt8] {
        get {
            if (!super.payload.isEmpty) {
                return super.payload
            }

            var payload:[UInt8] = []
            payload += serializer.serialize(handlerName)
            for arg in arguments {
                payload += serializer.serialize(arg)
            }
            super.payload = payload

            return super.payload
        }
        set {
            if (super.payload == newValue) {
                return
            }

            if (length == newValue.count) {
                var positon:Int = 0
                var bytes:[UInt8] = newValue
                handlerName = serializer.deserialize(&bytes, &positon)
                arguments.append(serializer.deserialize(&bytes, &positon))
            }

            super.payload = newValue
        }
    }

    override init() {
        super.init()
    }

    init(objectEncoding:UInt8) {
        super.init()
        self.objectEncoding = objectEncoding
        self.serializer = objectEncoding == 0x00 ? AMF0Serializer() : AMF3Serializer()
    }

    init(streamId:UInt32, objectEncoding:UInt8, handlerName:String, arguments:[Any?]) {
        super.init()
        self.streamId = streamId
        self.objectEncoding = objectEncoding
        self.handlerName = handlerName
        self.arguments = arguments
        self.serializer = objectEncoding == 0x00 ? AMF0Serializer() : AMF3Serializer()
    }

    convenience init(streamId:UInt32, objectEncoding:UInt8, handlerName:String) {
        self.init(streamId: streamId, objectEncoding: objectEncoding, handlerName: handlerName, arguments: [])
    }

    override func execute(connection: RTMPConnection) {
        guard let stream:RTMPStream = connection.streams[streamId] else {
            return
        }
        stream.recorder.onMessage(data: self)
    }
}

/**
 * @see 7.1.3. Shared Object Message (19, 16)
 */
final class RTMPSharedObjectMessage:RTMPMessage {

    struct Event: CustomStringConvertible {
        enum Type:UInt8 {
            case Use = 1
            case Release = 2
            case RequestChange = 3
            case Change = 4
            case Success = 5
            case SendMessage = 6
            case Status = 7
            case Clear = 8
            case Remove = 9
            case RequestRemove = 10
            case UseSuccess = 11
            case Unknown = 255
        }

        var type:Type = .Unknown
        var name:String? = nil
        var data:Any? = nil

        var description:String {
            var description:String = "Event{"
            description += "type:\(type),"
            description += "name:\(name),"
            description += "data:\(data)"
            description += "}"
            return description
        }

        init(type:Type) {
            self.type = type
        }

        init(type:Type, name:String, data:Any?) {
            self.type = type
            self.name = name
            self.data = data
        }

        init(bytes:[UInt8], inout position:Int, serializer:AMFSerializer) {
            type = Type(rawValue: bytes[position++])!
            guard 0 < UInt32(bytes: Array(bytes[position..<position + 4])).bigEndian else {
                position += 4
                return
            }
            position += 4
            let length:Int = Int(UInt16(bytes: Array(bytes[position..<position + 2])).bigEndian)
            position += 2
            name = String(bytes: Array(bytes[position..<position + length]), encoding: NSUTF8StringEncoding)!
            position += length
            if (position < bytes.count) {
                var value:[UInt8] = bytes
                data = serializer.deserialize(&value, &position)
            }
        }
    }

    override var type:Type {
        return objectEncoding == 0x00 ? .AMF0Shared : .AMF3Shared
    }

    var objectEncoding:UInt8 = RTMPConnection.defaultObjectEncoding {
        didSet {
            serializer = objectEncoding == 0x00 ? AMF0Serializer() : AMF3Serializer()
        }
    }

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

    var events:[Event]! = nil {
        didSet {
            super.payload.removeAll(keepCapacity: false)
        }
    }

    override var description: String {
        var description:String = "RTMPSharedObjectMessage{"
        description += "timestmap:\(timestamp),"
        description += "objectEncoding:\(objectEncoding),"
        description += "sharedObjectName:\(sharedObjectName),"
        description += "currentVersion:\(currentVersion),"
        description += "flags:\(flags),"
        description += "events:\(events)"
        description += "}"
        return description
    }

    override var payload:[UInt8] {
        get {
            guard super.payload.isEmpty else {
                return super.payload
            }

            let buffer:[UInt8] = [UInt8](sharedObjectName.utf8)
            super.payload += UInt16(buffer.count).bigEndian.bytes
            super.payload += buffer
            super.payload += currentVersion.bigEndian.bytes
            super.payload += flags

            for event in events {
                super.payload += [event.type.rawValue]
                if (event.data != nil) {
                    let name:[UInt8] = [UInt8](event.name!.utf8)
                    let data:[UInt8] = serializer.serialize(event.data)
                    super.payload += UInt32(name.count + data.count + 2).bigEndian.bytes
                    super.payload += UInt16(name.count).bigEndian.bytes
                    super.payload += name
                    super.payload += data
                } else {
                    super.payload += UInt32(0).bytes
                }
            }

            return super.payload
        }
        set {
            if (super.payload == newValue) {
                return
            }
            if (length == newValue.count) {
                var position:Int = Int(UInt16(bytes: Array(newValue[0..<2])).bigEndian) + 2
                sharedObjectName = String(bytes: Array(newValue[2..<position]), encoding: NSUTF8StringEncoding)!
                currentVersion = UInt32(bytes: Array(newValue[position..<position + 4])).bigEndian
                position += 4
                flags = Array(newValue[position..<position + 8])
                position += 8
                events = []
                while (position < newValue.count) {
                    events.append(Event(bytes: newValue, position: &position, serializer: serializer))
                }
            }
            super.payload = newValue
        }
    }

    private var serializer:AMFSerializer = RTMPConnection.defaultObjectEncoding == 0x00 ? AMF0Serializer() : AMF3Serializer()

    init(objectEncoding:UInt8) {
        super.init()
        self.objectEncoding = objectEncoding
        self.serializer = objectEncoding == 0x00 ? AMF0Serializer() : AMF3Serializer()
    }

    init(timestamp:UInt32, objectEncoding:UInt8, sharedObjectName:String, currentVersion:UInt32, flags:[UInt8], events:[Event]) {
        super.init()
        self.timestamp = timestamp
        self.objectEncoding = objectEncoding
        self.sharedObjectName = sharedObjectName
        self.currentVersion = currentVersion
        self.flags = flags
        self.events = events
    }

    override func execute(connection:RTMPConnection) {
        let persistence:Bool = flags[0] == 0x01
        RTMPSharedObject.getRemote(sharedObjectName, remotePath: connection.uri!.absoluteWithoutQueryString, persistence: persistence).onMessage(self)
    }
}

/**
 * @see 7.1.5. Audio Message (9)
 */
class RTMPAudioMessage:RTMPMessage {

    override var type:Type {
        return .Audio
    }

    override init() {
        super.init()
    }

    init (streamId: UInt32, timestamp: UInt32, buffer:NSData) {
        super.init()
        self.streamId = streamId
        self.timestamp = timestamp
        payload = [UInt8](count: buffer.length, repeatedValue: 0x00)
        buffer.getBytes(&payload, length: payload.count)
    }

    override func execute(connection:RTMPConnection) {
        guard let stream:RTMPStream = connection.streams[streamId] else {
            return
        }
        stream.audioPlayback.onMessage(self)
        stream.recorder.onMessage(audio: self)
    }
}

/**
* @see 7.1.5. Video Message (9)
*/
final class RTMPVideoMessage:RTMPAudioMessage {

    override var type:Type {
        return .Video
    }

    override func execute(connection:RTMPConnection) {
        guard let stream:RTMPStream = connection.streams[streamId] else {
            return
        }
        stream.recorder.onMessage(video: self)
        if (payload.count <= FLVTag.TagType.Video.headerSize) {
            return
        }
        switch payload[1] {
        case FLVTag.AVCPacketType.Seq.rawValue:
            createFormatDescription(stream)
        case FLVTag.AVCPacketType.Nal.rawValue:
            if (!stream.readyForKeyframe) {
                stream.readyForKeyframe = (payload[0] >> 4 == FLVTag.FrameType.Key.rawValue)
                if (stream.readyForKeyframe) {
                    enqueueSampleBuffer(stream)
                }
            } else {
                enqueueSampleBuffer(stream)
            }
        default:
            break
        }
    }

    func enqueueSampleBuffer(stream: RTMPStream) {
        guard let _:FLVTag.FrameType = FLVTag.FrameType(rawValue: payload[0] >> 4) else {
            return
        }

        var bytes:[UInt8] = Array(payload[FLVTag.TagType.Video.headerSize..<payload.count])
        let sampleSize:Int = bytes.count

        var blockBuffer:CMBlockBufferRef?
        guard CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault, &bytes, sampleSize, kCFAllocatorNull, nil, 0, sampleSize, 0, &blockBuffer) == noErr else {
            return
        }

        var sampleBuffer:CMSampleBufferRef?
        var sampleSizes:[Int] = [sampleSize]
        var timing:CMSampleTimingInfo = CMSampleTimingInfo()
        timing.duration = CMTimeMake(Int64(timestamp), 1000)
        
        guard CMSampleBufferCreate(kCFAllocatorDefault, blockBuffer!, true, nil, nil, stream.videoFormatDescription!, 1, 1, &timing, 1, &sampleSizes, &sampleBuffer) == noErr else {
            return
        }

        let naluType:NALUType? = NALUType(bytes: bytes, naluLength: 4)
        let attachments:CFArrayRef = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer!, true)!
        for i:CFIndex in 0..<CFArrayGetCount(attachments) {
            naluType?.setCMSampleAttachmentValues(unsafeBitCast(CFArrayGetValueAtIndex(attachments, i), CFMutableDictionaryRef.self
                ))
        }

        stream.enqueueSampleBuffer(video: sampleBuffer!)
    }

    func createFormatDescription(stream: RTMPStream) -> OSStatus{
        var config:AVCConfigurationRecord = AVCConfigurationRecord()
        config.bytes = Array(payload[5..<payload.count])
        return config.createFormatDescription(&stream.videoFormatDescription)
    }
}


/**
 * @see 7.1.6. Aggregate Message (22)
 */
final class RTMPAggregateMessage:RTMPMessage {
    override var type:Type {
        return .Aggregate
    }
}

/**
 * @see 7.1.7. User Control Message Events
 */
final class RTMPUserControlMessage:RTMPMessage {

    enum Event:UInt8 {
        case StreamBegin = 0x00
        case StreamEof = 0x01
        case StreamDry = 0x02
        case SetBuffer = 0x03
        case Recorded = 0x04
        case Ping = 0x06
        case Pong = 0x07
        case BufferEmpty = 0x1F
        case BufferFull = 0x20
        case Unknown = 0xFF

        var bytes:[UInt8] {
            return [0x00, rawValue]
        }
    }

    override var type:Type {
        return .User
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
            if (!super.payload.isEmpty) {
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

    override var description: String {
        var description:String = "RTMPUserControlMessage{"
        description += "event:\(event),"
        description += "value:\(value)"
        description += "}"
        return description
    }

    override init() {
        super.init()
    }
    
    init(event:Event) {
        super.init()
        self.event = event
    }

    override func execute(connection: RTMPConnection) {
        switch event {
        case .Ping:
            connection.socket.doWrite(RTMPChunk(message: RTMPUserControlMessage(event: .Pong)))
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
