import Foundation

public struct MoQTGoaway: MoQTControlMessage {
    public let type: MoQTMessageType = .goaway
    public let newSessionURI: String

    public var payload: Data {
        get throws {
            var payload = MoQTPayload()
            payload.putString(newSessionURI)
            return payload.data
        }
    }
}

extension MoQTGoaway {
    init(_ payload: inout MoQTPayload) throws {
        newSessionURI = try payload.getString()
    }
}
