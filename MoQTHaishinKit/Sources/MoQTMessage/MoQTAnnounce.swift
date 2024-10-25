import Foundation
import Logboard

/// 6.21. ANNOUNCE
public struct MoQTAnnounce: MoQTMessage {
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

    public init(trackNamespace: [String], subscribeParameters: [MoQTVersionSpecificParameter]) {
        self.trackNamespace = trackNamespace
        self.subscribeParameters = subscribeParameters
    }

    public struct Ok: MoQTMessage {
        public let type = MoQTMessageType.announceOk
        public let trackNamespace: [String]

        public var payload: Data {
            get throws {
                throw MoQTMessageError.notImplemented
            }
        }

        init(_ payload: inout MoQTPayload) throws {
            let trackNamespaceCounts = try payload.getInt()
            var trackNamespace: [String] = .init()
            for _ in 0..<trackNamespaceCounts {
                trackNamespace.append(try payload.getString())
            }
            self.trackNamespace = trackNamespace
        }
    }

    public struct Error: MoQTMessage, Swift.Error {
        public let type = MoQTMessageType.announceError
        public let trackNamespace: [String]
        public let code: Int
        public let reasonPhrase: String

        public var payload: Data {
            get throws {
                throw MoQTMessageError.notImplemented
            }
        }

        init(_ payload: inout MoQTPayload) throws {
            let trackNamespaceCounts = try payload.getInt()
            var trackNamespace: [String] = .init()
            for _ in 0..<trackNamespaceCounts {
                trackNamespace.append(try payload.getString())
            }
            self.trackNamespace = trackNamespace
            code = try payload.getInt()
            reasonPhrase = try payload.getString()
        }
    }
}
