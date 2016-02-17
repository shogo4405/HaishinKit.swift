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
    var persistence:Bool
    var currentVersion:UInt32 = 0

    public var objectEncoding:UInt8 = RTMPConnection.defaultObjectEncoding
    public private(set) var data:[String: Any?] = [:]

    override public var description:String {
        return data.description
    }

    private var rtmpConnection:RTMPConnection? = nil

    init (name:String, path:String, persistence:Bool) {
        self.name = name
        self.path = path
        self.persistence = persistence
        super.init()
    }

    public func setProperty(name:String, value:Any?) {
        data[name] = value
        guard let rtmpConnection:RTMPConnection = rtmpConnection where rtmpConnection.connected else {
            return
        }
        let event:RTMPSharedObjectMessage.Event = RTMPSharedObjectMessage.Event(type: .RequestChange, name: name, data: value)
        rtmpConnection.doWrite(createChunk([event]))
    }

    public func connect(rtmpConnection:RTMPConnection) {
        if (self.rtmpConnection != nil) {
            close()
        }
        self.rtmpConnection = rtmpConnection
        rtmpConnection.addEventListener(Event.RTMP_STATUS, selector: "rtmpConnection_rtmpStatusHandler:", observer: self)
        if (rtmpConnection.connected) {
            rtmpConnection.doWrite(createChunk([RTMPSharedObjectMessage.Event(type: .Use)]))
        }
    }

    public func clear() {
        data.removeAll(keepCapacity: false)
        rtmpConnection?.doWrite(createChunk([RTMPSharedObjectMessage.Event(type: .Clear)]))
    }

    public func close() {
        data.removeAll(keepCapacity: false)
        rtmpConnection?.removeEventListener(Event.RTMP_STATUS, selector: "rtmpConnection_rtmpStatusHandler:", observer: self)
        rtmpConnection?.doWrite(createChunk([RTMPSharedObjectMessage.Event(type: .Release)]))
        rtmpConnection = nil
    }

    final func onMessage(message:RTMPSharedObjectMessage) {
        currentVersion = message.currentVersion
        var changeList:[[String:Any?]] = []
        for event in message.events {
            var change:[String:Any?] = [
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
                break
            default:
                break
            }
            changeList.append(change)
        }
        dispatchEventWith(Event.SYNC, bubbles: false, data: changeList)
    }

    func createChunk(events:[RTMPSharedObjectMessage.Event]) -> RTMPChunk {
        return RTMPChunk(message: RTMPSharedObjectMessage(
            objectEncoding: objectEncoding,
            sharedObjectName: name,
            currentVersion: currentVersion,
            flags: [persistence ? 0x01 : 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00],
            events: events
        ))
    }

    func rtmpConnection_rtmpStatusHandler(notification:NSNotification) {
        let e:Event = Event.from(notification)
        if let data:ECMAObject = e.data as? ECMAObject, code:String = data["code"] as? String {
            switch code {
            case RTMPConnection.Code.ConnectSuccess.rawValue:
                rtmpConnection?.doWrite(createChunk([RTMPSharedObjectMessage.Event(type: .Use)]))
            default:
                break
            }
        }
    }
}
