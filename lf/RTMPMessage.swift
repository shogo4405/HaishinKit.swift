import Foundation

enum RTMPMessageType:UInt8 {
    case CHUNK_SIZE = 1
    case ABORT = 2
    case ACK = 3
    case USER = 4
    case WINDOW_ACK = 5
    case BANDWIDTH = 6
    case AUDIO = 8
    case VIDEO = 9
    case AMF3_DATA = 15
    case AMF3_SHARED = 16
    case AMF3_COMMAND = 17
    case AMF0_DATA = 18
    case AMF0_SHARED = 19
    case AMF0_COMAND = 20
    case AGGREGATE = 22
    case UNKNOW = 255
}

class RTMPMessage: NSObject {
    static func create(type:UInt8) -> RTMPMessage {
        switch type {
        case RTMPMessageType.CHUNK_SIZE.rawValue:
            return RTMPSetChunkSizeMessage()
        case RTMPMessageType.ACK.rawValue:
            return RTMPAcknowledgementMessage();
        case RTMPMessageType.USER.rawValue:
            return RTMPUserControlMessage()
        case RTMPMessageType.WINDOW_ACK.rawValue:
            return RTMPWindowAcknowledgementSizeMessage()
        case RTMPMessageType.BANDWIDTH.rawValue:
            return RTMPSetPeerBandwidthMessage()
        case RTMPMessageType.AMF0_DATA.rawValue:
            return RTMPDataMessage()
        case RTMPMessageType.AMF0_COMAND.rawValue:
            let message:RTMPCommandMessage = RTMPCommandMessage()
            message.objectEncoding = 0x00
            return message
        case RTMPMessageType.AMF3_COMMAND.rawValue:
            let message:RTMPCommandMessage = RTMPCommandMessage()
            message.objectEncoding = 0x03
            return message
        default:
            return RTMPMessage(type: RTMPMessageType(rawValue: type)!)
        }
    }

    private var _type:RTMPMessageType = RTMPMessageType.UNKNOW

    var type:RTMPMessageType {
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

    init(type:RTMPMessageType) {
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


final class RTMPSetChunkSizeMessage:RTMPMessage {
    
    override var type:RTMPMessageType {
        return RTMPMessageType.CHUNK_SIZE
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

final class RTMPSetPeerBandwidthMessage:RTMPMessage {
    
    enum LIMIT:UInt8 {
        case HARD = 0x00
        case SOFT = 0x01
        case DYNAMIC = 0x10
    }
    
    override var type:RTMPMessageType {
        get {
            return RTMPMessageType.BANDWIDTH
        }
    }

    var size:Int32 = 0 {
        didSet {
            super.payload.removeAll(keepCapacity: false)
        }
    }

    var limit:LIMIT = LIMIT.HARD {
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

final class RTMPAcknowledgementMessage: RTMPMessage {
    override var type:RTMPMessageType {
        return RTMPMessageType.ACK
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

final class RTMPCommandMessage: RTMPMessage {
    
    var objectEncoding:UInt8 = 0x00
    
    override var type:RTMPMessageType {
        return objectEncoding == 0x00 ? RTMPMessageType.AMF0_COMAND : RTMPMessageType.AMF3_COMMAND
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
            
            super.payload += amf.serialize(commandName)
            super.payload += amf.serialize(transactionId)
            super.payload += amf.serialize(commandObject)
            
            for i in arguments {
                super.payload += amf.serialize(i)
            }
            
            return super.payload
        }
        set {
            if (super.payload == newValue) {
                return
            }

            if (length == newValue.count) {
                var pos:Int = 0
                commandName = amf.deserialize(newValue, position: &pos)
                transactionId = amf.deserialize(newValue, position: &pos)
                commandObject = amf.deserialize(newValue, position: &pos)

                arguments = []
                arguments.append(amf.deserialize(newValue, position: &pos))
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
    
    private var amf:AMFSerializer = AMF0Serializer()
    
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
    }
}

final class RTMPDataMessage:RTMPMessage {

    override var type:RTMPMessageType {
        return RTMPMessageType.AMF0_DATA
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
        _type = type == RTMPSampleType.VIDEO ? RTMPMessageType.VIDEO : RTMPMessageType.AUDIO
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

enum RTMPUserControlEvent:UInt8 {
    case STREAM_BEGIN = 0x00
    case STREAM_EOF = 0x01
    case STREAM_DRY = 0x02
    case SET_BUFFER = 0x03
    case RECORDED = 0x04
    case PING = 0x06
    case PONG = 0x07
    case BUFFER_EMPTY = 0x1F
    case BUFFER_FULL = 0x20
    case UNKNOWN = 0xFF

    var description:String {
        switch self {
        case .STREAM_BEGIN:
            return "NetStream.Begin"
        case .STREAM_DRY:
            return "NetStream.Dry"
        case .STREAM_EOF:
            return "NetStream.EOF"
        case .SET_BUFFER:
            return "SetBuffer.Length"
        case .RECORDED:
            return "StreamId.Recorded"
        case .PING:
            return "Ping"
        case .PONG:
            return "Pong"
        case .BUFFER_EMPTY:
            return "NetStream.Buffer.Empty"
        case .BUFFER_FULL:
            return "NetStream.Buffer.Full"
        default:
            return "UNKNOW"
        }
    }
}

final class RTMPUserControlMessage:RTMPMessage {

    override var type:RTMPMessageType {
        return RTMPMessageType.USER
    }

    var event:RTMPUserControlEvent = RTMPUserControlEvent.UNKNOWN {
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

            let event:RTMPUserControlEvent? = RTMPUserControlEvent(rawValue: newValue[1])
            if (event != nil) {
                self.event = event!
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
    
    init(event:RTMPUserControlEvent) {
        super.init()
        self.event = event
    }
}


final class RTMPWindowAcknowledgementSizeMessage:RTMPMessage {
    
    override var type:RTMPMessageType {
        return RTMPMessageType.WINDOW_ACK
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
