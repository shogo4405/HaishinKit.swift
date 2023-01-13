import Foundation

enum RTMPSharedObjectType: UInt8 {
    case use = 1
    case release = 2
    case requestChange = 3
    case change = 4
    case success = 5
    case sendMessage = 6
    case status = 7
    case clear = 8
    case remove = 9
    case requestRemove = 10
    case useSuccess = 11
    case unknown = 255
}

struct RTMPSharedObjectEvent {
    var type: RTMPSharedObjectType = .unknown
    var name: String?
    var data: Any?

    init(type: RTMPSharedObjectType) {
        self.type = type
    }

    init(type: RTMPSharedObjectType, name: String, data: Any?) {
        self.type = type
        self.name = name
        self.data = data
    }

    init?(serializer: inout AMFSerializer) throws {
        guard let byte: UInt8 = try? serializer.readUInt8(), let type = RTMPSharedObjectType(rawValue: byte) else {
            return nil
        }
        self.type = type
        let length = Int(try serializer.readUInt32())
        let position: Int = serializer.position
        if 0 < length {
            name = try serializer.readUTF8()
            switch type {
            case .status:
                data = try serializer.readUTF8()
            default:
                if serializer.position - position < length {
                    data = try serializer.deserialize()
                }
            }
        }
    }

    func serialize(_ serializer: inout AMFSerializer) {
        serializer.writeUInt8(type.rawValue)
        guard let name: String = name else {
            serializer.writeUInt32(0)
            return
        }
        let position: Int = serializer.position
        serializer
            .writeUInt32(0)
            .writeUInt16(UInt16(name.utf8.count))
            .writeUTF8Bytes(name)
            .serialize(data)
        let size: Int = serializer.position - position
        serializer.position = position
        serializer.writeUInt32(UInt32(size) - 4)
        let length = serializer.length
        serializer.position = length
    }
}

extension RTMPSharedObjectEvent: CustomDebugStringConvertible {
    // MARK: CustomDebugStringConvertible
    var debugDescription: String {
        Mirror(reflecting: self).debugDescription
    }
}

// MARK: -
/// The RTMPSharedObject class is used to read and write data on a server.
public class RTMPSharedObject: EventDispatcher {
    private static var remoteSharedObjects: [String: RTMPSharedObject] = [:]

    /// Returns a reference to a shared object on a server.
    public static func getRemote(withName: String, remotePath: String, persistence: Bool) -> RTMPSharedObject {
        let key: String = remotePath + "/" + withName + "?persistence=" + persistence.description
        objc_sync_enter(remoteSharedObjects)
        if remoteSharedObjects[key] == nil {
            remoteSharedObjects[key] = RTMPSharedObject(name: withName, path: remotePath, persistence: persistence)
        }
        objc_sync_exit(remoteSharedObjects)
        return remoteSharedObjects[key]!
    }

    var name: String
    var path: String
    var timestamp: TimeInterval = 0
    var persistence: Bool
    var currentVersion: UInt32 = 0

    /// The AMF object encoding type.
    public let objectEncoding: RTMPObjectEncoding = RTMPConnection.defaultObjectEncoding
    /// The current data storage.
    public private(set) var data: [String: Any?] = [:]

    private var succeeded = false {
        didSet {
            guard succeeded else {
                return
            }
            for (key, value) in data {
                setProperty(key, value)
            }
        }
    }

    private var rtmpConnection: RTMPConnection?

    init(name: String, path: String, persistence: Bool) {
        self.name = name
        self.path = path
        self.persistence = persistence
        super.init()
    }

    /// Updates the value of a property in shared object.
    public func setProperty(_ name: String, _ value: Any?) {
        data[name] = value
        guard let rtmpConnection: RTMPConnection = rtmpConnection, succeeded else {
            return
        }
        rtmpConnection.socket.doOutput(chunk: createChunk([
            RTMPSharedObjectEvent(type: .requestChange, name: name, data: value)
        ]), locked: nil)
    }

    /// Connects to a remove shared object on a server.
    public func connect(_ rtmpConnection: RTMPConnection) {
        if self.rtmpConnection != nil {
            close()
        }
        self.rtmpConnection = rtmpConnection
        rtmpConnection.addEventListener(.rtmpStatus, selector: #selector(rtmpStatusHandler), observer: self)
        if rtmpConnection.connected {
            timestamp = rtmpConnection.socket.timestamp
            rtmpConnection.socket.doOutput(chunk: createChunk([RTMPSharedObjectEvent(type: .use)]), locked: nil)
        }
    }

    /// Purges all of the data.
    public func clear() {
        data.removeAll(keepingCapacity: false)
        rtmpConnection?.socket.doOutput(chunk: createChunk([RTMPSharedObjectEvent(type: .clear)]), locked: nil)
    }

    /// Closes the connection a server.
    public func close() {
        data.removeAll(keepingCapacity: false)
        rtmpConnection?.removeEventListener(.rtmpStatus, selector: #selector(rtmpStatusHandler), observer: self)
        rtmpConnection?.socket.doOutput(chunk: createChunk([RTMPSharedObjectEvent(type: .release)]), locked: nil)
        rtmpConnection = nil
    }

    final func on(message: RTMPSharedObjectMessage) {
        currentVersion = message.currentVersion
        var changeList: [[String: Any?]] = []
        for event in message.events {
            var change: [String: Any?] = [
                "code": "",
                "name": event.name,
                "oldValue": nil
            ]
            switch event.type {
            case .change:
                change["code"] = "change"
                change["oldValue"] = data.removeValue(forKey: event.name!)
                data[event.name!] = event.data
            case .success:
                change["code"] = "success"
            case .status:
                change["code"] = "reject"
                change["oldValue"] = data.removeValue(forKey: event.name!)
            case .clear:
                data.removeAll(keepingCapacity: false)
                change["code"] = "clear"
            case .remove:
                change["code"] = "delete"
            case .useSuccess:
                succeeded = true
                continue
            default:
                continue
            }
            changeList.append(change)
        }
        dispatch(.sync, bubbles: false, data: changeList)
    }

    func createChunk(_ events: [RTMPSharedObjectEvent]) -> RTMPChunk {
        let now = Date()
        let timestamp: TimeInterval = now.timeIntervalSince1970 - self.timestamp
        self.timestamp = now.timeIntervalSince1970
        defer {
            currentVersion += 1
        }
        return RTMPChunk(
            type: succeeded ? .one : .zero,
            streamId: RTMPChunk.StreamID.command.rawValue,
            message: RTMPSharedObjectMessage(
                timestamp: UInt32(timestamp * 1000),
                objectEncoding: objectEncoding,
                sharedObjectName: name,
                currentVersion: succeeded ? 0 : currentVersion,
                flags: Data([0x00, 0x00, 0x00, persistence ? 0x02 : 0x00, 0x00, 0x00, 0x00, 0x00]),
                events: events
            )
        )
    }

    @objc
    private func rtmpStatusHandler(_ notification: Notification) {
        let e = Event.from(notification)
        if let data: ASObject = e.data as? ASObject, let code: String = data["code"] as? String {
            switch code {
            case RTMPConnection.Code.connectSuccess.rawValue:
                timestamp = rtmpConnection!.socket.timestamp
                rtmpConnection!.socket.doOutput(chunk: createChunk([RTMPSharedObjectEvent(type: .use)]), locked: nil)
            default:
                break
            }
        }
    }
}

extension RTMPSharedObject: CustomDebugStringConvertible {
    // MARK: CustomDebugStringConvertible
    public var debugDescription: String {
        data.debugDescription
    }
}
