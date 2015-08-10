import Foundation

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
        case Type.Ack.rawValue:
            return RTMPAcknowledgementMessage();
        case Type.User.rawValue:
            return RTMPUserControlMessage()
        case Type.WindowAck.rawValue:
            return RTMPWindowAcknowledgementSizeMessage()
        case Type.Bandwidth.rawValue:
            return RTMPSetPeerBandwidthMessage()
        case Type.AMF0Data.rawValue:
            return RTMPDataMessage()
        case Type.AMF0Command.rawValue:
            let message:RTMPCommandMessage = RTMPCommandMessage()
            message.objectEncoding = 0x00
            return message
        case Type.AMF3Command.rawValue:
            let message:RTMPCommandMessage = RTMPCommandMessage()
            message.objectEncoding = 0x03
            return message
        default:
            return RTMPMessage(type: Type(rawValue: type)!)
        }
    }

    private var _type:Type = Type.Unknown
    var type:Type {
        return _type
    }

    var length:Int = 0
    var streamId:UInt32 = 0
    var timestamp:UInt32 = 0
    var payload:[UInt8] = []

    var ready:Bool {
        return payload.count == length
    }

    override var description:String {
        var className:NSString = NSStringFromClass(self.dynamicType).componentsSeparatedByString(".").last! as String
        var description:String = "\(className){"
        description += "type:" + type.rawValue.description + ","
        description += "length:" + length.description + ","
        description += "streamId:" + streamId.description + ","
        description += "timestamp:" + timestamp.description + ","
        description += "payload:" + payload.count.description
        description += "}"
        return description
    }

    override init() {
        super.init()
    }

    init(type:Type) {
        _type = type
    }

    func append(bytes:[UInt8], chunkSize:Int) -> Int {
        if (ready) {
            return 0
        }

        var length:Int = self.length - payload.count
        if (bytes.count < length) {
            length = bytes.count
        }
        payload += Array(bytes[0..<length])

        return length
    }
}

/**
 * @see 5.4.1. Set Chunk Size (1)
 */
final class RTMPSetChunkSizeMessage:RTMPMessage {
    
    override var type:Type {
        return .ChunkSize
    }
    
    var size:Int32 = 0 {
        didSet {
            super.payload.removeAll(keepCapacity: false)
        }
    }

    override init() {
        super.init()
    }

    init (size:Int32) {
        super.init()
        self.size = size
    }
    
    override var payload:[UInt8] {
        get {
            if (!super.payload.isEmpty) {
                return super.payload
            }
            super.payload = size.bytes.reverse();
            return super.payload
        }
        set {
            if (super.payload == newValue) {
                return
            }
            size = Int32(bytes: newValue.reverse())
            super.payload = newValue
        }
    }
    
}

/**
 * 5.4.2. Abort Message (2)
 */
final class RTMPAbortMessge: RTMPMessage {
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
            super.payload = sequence.bytes.reverse()
            return super.payload
        }
        set {
            if (super.payload == newValue) {
                return
            }
            sequence = UInt32(bytes: newValue.reverse())
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
            super.payload = size.bytes.reverse()
            return super.payload
        }
        set {
            if (super.payload == newValue) {
                return
            }
            size = UInt32(bytes: newValue.reverse())
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
    }
    
    override var type:Type {
        get {
            return .Bandwidth
        }
    }
    
    var size:Int32 = 0 {
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
            payload += Int32(size).bytes.reverse()
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

    var commandObject:ECMAObject? = nil {
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
                commandName = serializer.deserialize(newValue, position: &position)
                transactionId = serializer.deserialize(newValue, position: &position)
                commandObject = serializer.deserialize(newValue, position: &position)
                arguments = []
                arguments.append(serializer.deserialize(newValue, position: &position))
            }
            super.payload = newValue
        }
    }
    
    override var description: String {
        var description:String = "RTMPCommandMessage{"
        description += "type:" + type.rawValue.description + ","
        description += "length:" + length.description + ","
        description += "streamId:" + streamId.description + ","
        description += "timestamp:" + timestamp.description + ","
        description += "commandName:" + commandName + ","
        description += "transactionId:" + transactionId.description + ","

        if (commandObject == nil) {
            description += "commandObject: null,"
        } else {
            description += "commandObject:" + commandObject!.description + ","
        }
        
        description += "arguments:"
        description += arguments.description
        description += "}"
        
        return description
    }

    private var serializer:AMFSerializer = RTMPConnection.defaultObjectEncoding == 0x00 ? AMF0Serializer() : AMF3Serializer()

    override init () {
        super.init()
    }
    
    init (streamId:UInt32, transactionId:Int, objectEncoding:UInt8, commandName:String, commandObject:ECMAObject?, arguments:[Any?]) {
        super.init()
        self.streamId = streamId
        self.transactionId = transactionId
        self.objectEncoding = objectEncoding
        self.commandName = commandName
        self.commandObject = commandObject
        self.arguments = arguments
        self.serializer = objectEncoding == 0x00 ? AMF0Serializer() : AMF3Serializer()
    }
}

/**
 * @see 7.1.2. Data Message (18, 15)
 */
final class RTMPDataMessage:RTMPMessage {

    override var type:Type {
        return .AMF0Data
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

    override var description: String {
        var description:String = "RTMPDataMessage{"
        description += "type:" + type.rawValue.description + ","
        description += "length:" + length.description + ","
        description += "streamId:" + streamId.description + ","
        description += "timestamp:" + timestamp.description + ","
        description += "handleName:" + handlerName + ","
        description += "arguments:" + arguments.description
        description += "}"
        return description
    }

    override var payload:[UInt8] {
        get {
            if (!super.payload.isEmpty) {
                return super.payload
            }

            var amf:AMF0Serializer = AMF0Serializer()
            var payload:[UInt8] = []

            payload += amf.serialize(handlerName)
            for arg in arguments {
                payload += amf.serialize(arg)
            }

            super.payload = payload
            
            return super.payload
        }
        set {
            if (super.payload == newValue) {
                return
            }

            if (length == newValue.count) {
                var amf:AMF0Serializer = AMF0Serializer()
                var positon:Int = 0
                handlerName = amf.deserialize(newValue, position: &positon)
                arguments.append(amf.deserialize(newValue, position: &positon))
            }

            super.payload = newValue
        }
    }

    override init () {
        super.init()
    }

    init(streamId:UInt32, objectEncoding:UInt8, handlerName:String, arguments:[Any?]) {
        super.init()
        self.streamId = streamId
        self.handlerName = handlerName
        self.arguments = arguments
    }

    convenience init(streamId:UInt32, objectEncoding:UInt8, handlerName:String) {
        self.init(streamId: streamId, objectEncoding: objectEncoding, handlerName: handlerName, arguments: [])
    }
}

/**
 * @see 7.1.3. Shared Object Message (19, 16)
 */
final class RTMPSharedObjectMessage:RTMPMessage {
    enum Event:UInt8 {
        case Use = 0
        case Release = 1
        case RequestChange = 2
        case Change = 3
        case Success = 5
        case SendMessage = 6
        case Status = 7
        case Clear = 8
        case Remove = 9
        case RequestRemove = 10
        case UseSuccess = 11
    }
}

/**
 * @see 7.1.4. Audio Message (8)
 * @see 7.1.5. Video Message (9)
 */
final class RTMPMediaMessage:RTMPMessage {
    var buffer:NSData? = nil {
        didSet {
            payload.removeAll(keepCapacity: false)
        }
    }

    init (streamId: UInt32, timestamp: UInt32, type:RTMPSampleType, buffer:NSData) {
        super.init()
        self.streamId = streamId
        self.timestamp = timestamp
        _type = type == RTMPSampleType.Audio ? Type.Audio : Type.Video
        self.buffer = buffer
    }

    override var payload:[UInt8] {
        get {
            if (!super.payload.isEmpty || buffer == nil) {
                return super.payload
            }
            var data:[UInt8] = [UInt8](count: buffer!.length, repeatedValue: 0x00)
            buffer!.getBytes(&data, length: data.count)
            super.payload = data
            return super.payload
        }
        set {
            if (super.payload == newValue) {
                return
            }
            super.payload = newValue
        }
    }
}

/**
 * @see 7.1.6. Aggregate Message (22)
 */
final class RTMPAggregateMessage:RTMPMessage {
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
        
        var description:String {
            switch self {
            case .StreamBegin:
                return "NetStream.Begin"
            case .StreamEof:
                return "NetStream.Dry"
            case .StreamDry:
                return "NetStream.EOF"
            case .SetBuffer:
                return "SetBuffer.Length"
            case .Recorded:
                return "StreamId.Recorded"
            case .Ping:
                return "Ping"
            case .Pong:
                return "Pong"
            case .BufferEmpty:
                return "NetStream.Buffer.Empty"
            case .BufferFull:
                return "NetStream.Buffer.Full"
            default:
                return "UNKNOW"
            }
        }
    }

    override var type:Type {
        return .User
    }

    var event:Event = Event.Unknown {
        didSet {
            super.payload.removeAll(keepCapacity: false)
        }
    }

    override var payload:[UInt8] {
        get {
            if (!super.payload.isEmpty) {
                return super.payload
            }
            var payload:[UInt8] = [UInt8](count:6, repeatedValue: 0)
            payload[1] = event.rawValue
            super.payload = payload
            return super.payload
        }
        set {
            if (super.payload == newValue) {
                return
            }
            if let event:Event = Event(rawValue: newValue[1]) {
                self.event = event
            }
            super.payload = newValue
        }
    }

    override var description: String {
        var description:String = "RTMPUserControlMessage{"
        description += "event:" + event.description + "(" + Array(payload[0..<2]).description + "),"
        description += "value:" + UInt32(bytes: Array(payload[2..<payload.count]).reverse()).description
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
}
