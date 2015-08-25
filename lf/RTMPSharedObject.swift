import Foundation

public class RTMPSharedObject: EventDispatcher {
    private static var remoteSharedObjects:Dictionary<String, RTMPSharedObject> = [:]

    public static func getRemote(name:String, remotePath:String, persistence:Bool) -> RTMPSharedObject {
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

    public var objectEncoding:UInt8 = RTMPConnection.defaultObjectEncoding

    private var rtmpConnection:RTMPConnection? = nil
    private var data:Dictionary<String, AnyObject?> = [:]

    init (name:String, path:String, persistence:Bool) {
        self.name = name
        self.path = path
        self.persistence = persistence
        super.init()
    }

    public func connect(rtmpConnection:RTMPConnection) {
        if (self.rtmpConnection != nil) {
            close()
        }
        self.rtmpConnection = rtmpConnection
        rtmpConnection.addEventListener("rtmpStatus", selector: "rtmpConnection_rtmpStatusHandler:", observer: self)
        if (rtmpConnection.connected) {
            rtmpConnection.doWrite(createChunk([RTMPSharedObjectMessage.Event(type: .Use)]))
        }
    }

    public func close() {
        rtmpConnection?.removeEventListener("rtmpStatus", selector: "rtmpConnection_rtmpStatusHandler:", observer: self)
        rtmpConnection?.doWrite(createChunk([RTMPSharedObjectMessage.Event(type: .Release)]))
        rtmpConnection = nil
    }

    func onMessage(message:RTMPSharedObjectMessage) {
        for event in message.events {
        }
    }

    func createChunk(events:[RTMPSharedObjectMessage.Event]) -> RTMPChunk {
        return RTMPChunk(message: RTMPSharedObjectMessage(
            objectEncoding: self.objectEncoding,
            sharedObjectName: name,
            flags: persistence,
            events: events
        ))
    }

    func rtmpConnection_rtmpStatusHandler(notification:NSNotification) {
        let e:Event = Event.from(notification)
        if let data:ECMAObject = e.data as? ECMAObject {
            if let code:String = data["code"] as? String {
                switch code {
                case "NetConnection.Connect.Success":
                    rtmpConnection!.doWrite(createChunk([RTMPSharedObjectMessage.Event(type: .Use)]))
                    break
                default:
                    break
                }
            }
        }
    }
}
