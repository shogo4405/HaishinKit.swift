import Foundation

/// 6.24. SUBSCRIBE_ANNOUNCES_OK
public struct MoQTSubscribeAnnouncesOk: MoQTControlMessage {
    public let type: MoQTMessageType = .subscribeAnnounucesOk
    public let trackNamespacePrefix: [String]

    public var payload: Data {
        get throws {
            throw MoQTControlMessageError.notImplemented
        }
    }
}

extension MoQTSubscribeAnnouncesOk {
    init(_ payload: inout MoQTPayload) throws {
        let length = try payload.getInt()
        var trackNamespacePrefix: [String] = .init()
        for _ in 0..<length {
            trackNamespacePrefix.append(try payload.getString())
        }
        self.trackNamespacePrefix = trackNamespacePrefix
    }
}
