import Foundation

/// 6.13. SUBSCRIBE_ANNOUNCES
public struct MoQTSubscribeAnnounces: MoQTControlMessage {
    public let type: MoQTMessageType = .subscribeAnnounuces
    public let trackNamespacePrefix: [String]
    public let parameters: [MoQTVersionSpecificParameter]

    public var payload: Data {
        get throws {
            var payload = MoQTPayload()
            payload.putInt(trackNamespacePrefix.count)
            for prefix in trackNamespacePrefix {
                payload.putString(prefix)
            }
            payload.putInt(parameters.count)
            for parameter in parameters {
                payload.putData(try parameter.payload)
            }
            return payload.data
        }
    }
}
