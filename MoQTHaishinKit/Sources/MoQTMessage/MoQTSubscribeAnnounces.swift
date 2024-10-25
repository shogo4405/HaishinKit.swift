import Foundation

/// 6.13. SUBSCRIBE_ANNOUNCES
public struct MoQTSubscribeAnnounces: MoQTMessage {
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

    /// 6.24. SUBSCRIBE_ANNOUNCES_OK
    public struct Ok: MoQTMessage {
        public let type: MoQTMessageType = .subscribeAnnounucesOk
        public let trackNamespacePrefix: [String]

        public var payload: Data {
            get throws {
                throw MoQTMessageError.notImplemented
            }
        }

        init(_ payload: inout MoQTPayload) throws {
            let length = try payload.getInt()
            var trackNamespacePrefix: [String] = .init()
            for i in 0..<length {
                trackNamespacePrefix.append(try payload.getString())
            }
            self.trackNamespacePrefix = trackNamespacePrefix
        }
    }

    /// 6.25. SUBSCRIBE_ANNOUNCES_ERROR
    public struct Error: MoQTMessage, Swift.Error {
        public let type: MoQTMessageType = .subscribeAnnounucesError
        public let trackNamespacePrefix: [String]
        public let errorCode: Int
        public let reasonPhrase: String

        public var payload: Data {
            get throws {
                throw MoQTMessageError.notImplemented
            }
        }

        init(_ payload: inout MoQTPayload) throws {
            let length = try payload.getInt()
            var trackNamespacePrefix: [String] = .init()
            for i in 0..<length {
                trackNamespacePrefix.append(try payload.getString())
            }
            self.trackNamespacePrefix = trackNamespacePrefix
            errorCode = try payload.getInt()
            reasonPhrase = try payload.getString()
        }
    }
}
