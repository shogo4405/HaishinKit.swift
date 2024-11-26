import Foundation
import Logboard

/// 6.21. ANNOUNCE
public struct MoQTAnnounce: MoQTControlMessage {
    public let type = MoQTMessageType.announce
    public let trackNamespace: [String]
    public let subscribeParameters: [MoQTVersionSpecificParameter]

    public var payload: Data {
        get throws {
            var payload = MoQTPayload()
            payload.putInt(trackNamespace.count)
            for namespace in trackNamespace {
                payload.putString(namespace)
            }
            payload.putInt(subscribeParameters.count)
            for parameter in subscribeParameters {
                do {
                    payload.putData(try parameter.payload)
                } catch {
                    logger.info(error)
                }
            }
            return payload.data
        }
    }
}
