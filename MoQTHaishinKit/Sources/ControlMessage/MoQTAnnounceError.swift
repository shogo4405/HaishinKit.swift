import Foundation
import Logboard

/// 6.21. ANNOUNCE
public struct MoQTAnnounceError: MoQTControlMessage, Swift.Error {
    public let type = MoQTMessageType.announceError
    public let trackNamespace: [String]
    public let code: Int
    public let reasonPhrase: String

    public var payload: Data {
        get throws {
            throw MoQTControlMessageError.notImplemented
        }
    }
}

extension MoQTAnnounceError {
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
