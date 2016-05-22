import Foundation

struct RTMPSharedObjectEvent {
    enum Type:UInt8 {
        case Use           = 1
        case Release       = 2
        case RequestChange = 3
        case Change        = 4
        case Success       = 5
        case SendMessage   = 6
        case Status        = 7
        case Clear         = 8
        case Remove        = 9
        case RequestRemove = 10
        case UseSuccess    = 11
        case Unknown       = 255
    }

    var type:Type = .Unknown
    var name:String? = nil
    var data:Any? = nil

    init(type:Type) {
        self.type = type
    }

    init(type:Type, name:String, data:Any?) {
        self.type = type
        self.name = name
        self.data = data
    }

    init?(serializer:AMFSerializer) throws {
        guard let type:Type = Type(rawValue: try serializer.readUInt8()) else {
            return nil
        }
        self.type = type
        let length:Int = Int(try serializer.readUInt32())
        let position:Int = serializer.position
        if (0 < length) {
            name = try serializer.readUTF8()
            if (serializer.position - position < length) {
                data = try serializer.deserialize()
            }
        }
    }

    func serialize(inout serializer:AMFSerializer) throws {
        serializer.writeUInt8(type.rawValue)
        guard let name:String = name else {
            serializer.writeUInt32(0)
            return
        }
        let position:Int = serializer.position
        serializer.writeUInt32(0)
        serializer.writeUInt16(UInt16(name.utf8.count))
        serializer.writeUTF8Bytes(name)
        serializer.serialize(data)
        let size:Int = serializer.position - position
        serializer.position = position
        serializer.writeUInt32(UInt32(size) - 4)
        serializer.position = serializer.length
    }
}

// MARK: CustomStringConvertible
extension RTMPSharedObjectEvent: CustomStringConvertible {
    var description:String {
        return Mirror(reflecting: self).description
    }
}

// MARK: -
/**
 flash.net.SharedObject for Swift
 */
public class RTMPSharedObject: EventDispatcher {

    static private var remoteSharedObjects:[String: RTMPSharedObject] = [:]
    static public func getRemote(name: String, remotePath: String, persistence: Bool) -> RTMPSharedObject {
        let key:String = remotePath + "/" + name + "?persistence=" + persistence.description
        objc_sync_enter(remoteSharedObjects)
        if (remoteSharedObjects[key] == nil) {
            remoteSharedObjects[key] = RTMPSharedObject(name: name, path: remotePath, persistence: persistence)
        }
        objc_sync_exit(remoteSharedObjects)
        return remoteSharedObjects[key]!
    }

    var name:String
    var path:String
    var timestamp:NSTimeInterval = 0
    var persistence:Bool
    var currentVersion:UInt32 = 0

    public private(set) var objectEncoding:UInt8 = RTMPConnection.defaultObjectEncoding
    public private(set) var data:[String: Any?] = [:]

    private var succeeded:Bool = false {
        didSet {
            guard succeeded else {
                return
            }
            for (key, value) in data {
                setProperty(key, value)
            }
        }
    }

    override public var description:String {
        return data.description
    }

    private var rtmpConnection:RTMPConnection? = nil

    init(name:String, path:String, persistence:Bool) {
        self.name = name
        self.path = path
        self.persistence = persistence
        super.init()
    }

    public func setProperty(name:String, _ value:Any?) {
        data[name] = value
        guard let rtmpConnection:RTMPConnection = rtmpConnection where succeeded else {
            return
        }
        rtmpConnection.socket.doOutput(chunk: createChunk([
            RTMPSharedObjectEvent(type: .RequestChange, name: name, data: value)
        ]))
    }

    public func connect(rtmpConnection:RTMPConnection) {
        if (self.rtmpConnection != nil) {
            close()
        }
        self.rtmpConnection = rtmpConnection
        rtmpConnection.addEventListener(Event.RTMP_STATUS, selector: #selector(RTMPSharedObject.rtmpStatusHandler(_:)), observer: self)
        if (rtmpConnection.connected) {
            timestamp = rtmpConnection.socket.timestamp
            rtmpConnection.socket.doOutput(chunk: createChunk([RTMPSharedObjectEvent(type: .Use)]))
        }
    }

    public func clear() {
        data.removeAll(keepCapacity: false)
        rtmpConnection?.socket.doOutput(chunk: createChunk([RTMPSharedObjectEvent(type: .Clear)]))
    }

    public func close() {
        data.removeAll(keepCapacity: false)
        rtmpConnection?.removeEventListener(Event.RTMP_STATUS, selector: #selector(RTMPSharedObject.rtmpStatusHandler(_:)), observer: self)
        rtmpConnection?.socket.doOutput(chunk: createChunk([RTMPSharedObjectEvent(type: .Release)]))
        rtmpConnection = nil
    }

    final func onMessage(message:RTMPSharedObjectMessage) {
        currentVersion = message.currentVersion
        var changeList:[[String: Any?]] = []
        for event in message.events {
            var change:[String: Any?] = [
                "code": "",
                "name": event.name,
                "oldValue": nil
            ]
            switch event.type {
            case .Change:
                change["code"] = "change"
                change["oldValue"] = data.removeValueForKey(event.name!)
                data[event.name!] = event.data
            case .Success:
                change["code"] = "success"
            case .Status:
                change["code"] = "reject"
                change["oldValue"] = data.removeValueForKey(event.name!)
            case .Clear:
                data.removeAll(keepCapacity: false)
                change["code"] = "clear"
            case .Remove:
                change["code"] = "delete"
            case .UseSuccess:
                succeeded = true
                continue
            default:
                continue
            }
            changeList.append(change)
        }
        dispatchEventWith(Event.SYNC, bubbles: false, data: changeList)
    }

    func createChunk(events:[RTMPSharedObjectEvent]) -> RTMPChunk {
        let now:NSDate = NSDate()
        let timestamp:NSTimeInterval = now.timeIntervalSince1970 - self.timestamp
        self.timestamp = now.timeIntervalSince1970
        defer {
            currentVersion += 1
        }
        return RTMPChunk(
            type: succeeded ? .One : .Zero,
            streamId: RTMPChunk.command,
            message: RTMPSharedObjectMessage(
                timestamp: UInt32(timestamp * 1000),
                objectEncoding: objectEncoding,
                sharedObjectName: name,
                currentVersion: succeeded ? 0 : currentVersion,
                flags: [persistence ? 0x01 : 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00],
                events: events
            )
        )
    }

    func rtmpStatusHandler(notification:NSNotification) {
        let e:Event = Event.from(notification)
        if let data:ASObject = e.data as? ASObject, code:String = data["code"] as? String {
            switch code {
            case RTMPConnection.Code.ConnectSuccess.rawValue:
                timestamp = rtmpConnection!.socket.timestamp
                rtmpConnection!.socket.doOutput(chunk: createChunk([RTMPSharedObjectEvent(type: .Use)]))
            default:
                break
            }
        }
    }
}
