import Foundation
import Logboard

public struct MoQTAnnounceOk: MoQTControlMessage {
    public let type = MoQTMessageType.announceOk
    public let trackNamespace: [String]

    public var payload: Data {
        get throws {
            throw MoQTControlMessageError.notImplemented
        }
    }
}

extension MoQTAnnounceOk {
    init(_ payload: inout MoQTPayload) throws {
        let trackNamespaceCounts = try payload.getInt()
        var trackNamespace: [String] = .init()
        for _ in 0..<trackNamespaceCounts {
            trackNamespace.append(try payload.getString())
        }
        self.trackNamespace = trackNamespace
    }
}
