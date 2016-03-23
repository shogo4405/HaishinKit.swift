import Foundation

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
        rtmpConnection.doWrite(createChunk([
            RTMPSharedObjectMessage.Event(type: .RequestChange, name: name, data: value)
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
            rtmpConnection.doWrite(createChunk([RTMPSharedObjectMessage.Event(type: .Use)]))
        }
    }

    public func clear() {
        data.removeAll(keepCapacity: false)
        rtmpConnection?.doWrite(createChunk([RTMPSharedObjectMessage.Event(type: .Clear)]))
    }

    public func close() {
        data.removeAll(keepCapacity: false)
        rtmpConnection?.removeEventListener(Event.RTMP_STATUS, selector: #selector(RTMPSharedObject.rtmpStatusHandler(_:)), observer: self)
        rtmpConnection?.doWrite(createChunk([RTMPSharedObjectMessage.Event(type: .Release)]))
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

    func createChunk(events:[RTMPSharedObjectMessage.Event]) -> RTMPChunk {
        let now:NSDate = NSDate()
        let timestamp:NSTimeInterval = now.timeIntervalSince1970 - self.timestamp
        self.timestamp = now.timeIntervalSince1970
        // post increment
        let currentVersion = self.currentVersion
        increment(&self.currentVersion)
        
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
                rtmpConnection!.doWrite(createChunk([RTMPSharedObjectMessage.Event(type: .Use)]))
            default:
                break
            }
        }
    }
}
