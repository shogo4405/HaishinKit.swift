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
    var data: (any Sendable)?

    init(type: RTMPSharedObjectType) {
        self.type = type
    }

    init(type: RTMPSharedObjectType, name: String, data: (any Sendable)?) {
        self.type = type
        self.name = name
        self.data = data
    }

    init?(serializer: inout any AMFSerializer) throws {
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

    func serialize(_ serializer: inout any AMFSerializer) {
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
public actor RTMPSharedObject {
    private static nonisolated(unsafe) var remoteSharedObjects: HKAtomic<[String: RTMPSharedObject]> = .init([:])

    /// Returns a reference to a shared object on a server.
    public static func getRemote(withName: String, remotePath: String, persistence: Bool) -> RTMPSharedObject {
        let key = remotePath + "/" + withName + "?persistence=" + persistence.description
        guard let sharedObject = remoteSharedObjects.value[key] else {
            let sharedObject = RTMPSharedObject(name: withName, path: remotePath, persistence: persistence)
            remoteSharedObjects.mutate { $0[key] = sharedObject }
            return sharedObject
        }
        return sharedObject
    }

    /// The AMF object encoding type.
    public let objectEncoding = RTMPConnection.defaultObjectEncoding
    /// The current data storage.
    public private(set) var data = AMFObject()

    private var succeeded = false {
        didSet {
            guard succeeded else {
                return
            }
            Task {
                for (key, value) in data {
                    await setProperty(key, value)
                }
            }
        }
    }

    let name: String
    let path: String
    var timestamp: TimeInterval = 0
    let persistence: Bool
    var currentVersion: UInt32 = 0
    private var connection: RTMPConnection?

    init(name: String, path: String, persistence: Bool) {
        self.name = name
        self.path = path
        self.persistence = persistence
    }

    /// Updates the value of a property in shared object.
    public func setProperty(_ name: String, _ value: (any Sendable)?) async {
        data[name] = value
        guard let connection, succeeded else {
            return
        }
        await connection.doOutput(.one, chunkStreamId: .command, message: makeMessage([RTMPSharedObjectEvent(type: .requestChange, name: name, data: value)]))
    }

    /// Connects to a remove shared object on a server.
    public func connect(_ rtmpConnection: RTMPConnection) async {
        if self.connection != nil {
            await close()
        }
        self.connection = rtmpConnection
        if await rtmpConnection.connected {
            await rtmpConnection.doOutput(.zero, chunkStreamId: .command, message: makeMessage([RTMPSharedObjectEvent(type: .use)]))
        }
    }

    /// Purges all of the data.
    public func clear() async {
        data.removeAll(keepingCapacity: false)
        await connection?.doOutput(.one, chunkStreamId: .command, message: makeMessage([RTMPSharedObjectEvent(type: .clear)]))
    }

    /// Closes the connection a server.
    public func close() async {
        data.removeAll(keepingCapacity: false)
        await connection?.doOutput(.one, chunkStreamId: .command, message: makeMessage([RTMPSharedObjectEvent(type: .release)]))
        connection = nil
    }

    final func on(message: RTMPSharedObjectMessage) {
        currentVersion = message.currentVersion
        var changeList: [AMFObject] = []
        for event in message.events {
            var change: AMFObject = [
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
    }

    private func makeMessage(_ events: [RTMPSharedObjectEvent]) -> RTMPSharedObjectMessage {
        let now = Date()
        let timestamp: TimeInterval = now.timeIntervalSince1970 - self.timestamp
        self.timestamp = now.timeIntervalSince1970
        defer {
            currentVersion += 1
        }
        return RTMPSharedObjectMessage(
            timestamp: UInt32(timestamp * 1000),
            streamId: 0,
            objectEncoding: objectEncoding,
            sharedObjectName: name,
            currentVersion: succeeded ? 0 : currentVersion,
            flags: Data([0x00, 0x00, 0x00, persistence ? 0x02 : 0x00, 0x00, 0x00, 0x00, 0x00]),
            events: events
        )
    }
}
