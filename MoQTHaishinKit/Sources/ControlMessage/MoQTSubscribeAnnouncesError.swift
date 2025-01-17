import Foundation

/// 6.25. SUBSCRIBE_ANNOUNCES_ERROR
public struct MoQTSubscribeAnnouncesError: MoQTControlMessage, Swift.Error {
    public let type: MoQTMessageType = .subscribeAnnounucesError
    public let trackNamespacePrefix: [String]
    public let errorCode: Int
    public let reasonPhrase: String

    public var payload: Data {
        get throws {
            throw MoQTControlMessageError.notImplemented
        }
    }
}

extension MoQTSubscribeAnnouncesError {
    init(_ payload: inout MoQTPayload) throws {
        let length = try payload.getInt()
        var trackNamespacePrefix: [String] = .init()
        for _ in 0..<length {
            trackNamespacePrefix.append(try payload.getString())
        }
        self.trackNamespacePrefix = trackNamespacePrefix
        errorCode = try payload.getInt()
        reasonPhrase = try payload.getString()
    }
}
