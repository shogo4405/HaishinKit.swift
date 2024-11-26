import Foundation

public struct MoQTSubscribeError: MoQTControlMessage, Swift.Error {
    public let type = MoQTMessageType.subscribeError
    public let subscribeId: Int
    public let code: Int
    public let reasonPhrase: String
    public let trackAlias: Int

    public var payload: Data {
        get throws {
            throw MoQTControlMessageError.notImplemented
        }
    }
}

extension MoQTSubscribeError {
    init(_ payload: inout MoQTPayload) throws {
        subscribeId = try payload.getInt()
        code = try payload.getInt()
        reasonPhrase = try payload.getString()
        trackAlias = try payload.getInt()
    }
}
