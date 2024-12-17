import Foundation

public enum MoQTVersionSpecificType: Int, Sendable {
    case authorizationInfo = 0x02
    case deliveryTimeout = 0x03
    case maxCacheDuration = 0x04
}

/// 6.1.1.  Version Specific Parameters
public struct MoQTVersionSpecificParameter: Sendable {
    enum Error: Swift.Error {
        case missionSetupParameterType
    }

    public let key: MoQTVersionSpecificType
    public let value: (any Sendable)

    var payload: Data {
        get throws {
            var payload = MoQTPayload()
            switch value {
            case let value as String:
                payload.putInt(key.rawValue)
                payload.putString(value)
                return payload.data
            case let value as MoQTSetupRole:
                payload.putInt(key.rawValue)
                payload.putInt(1)
                payload.putInt(value.rawValue)
                return payload.data
            default:
                throw MoQTControlMessageError.notImplemented
            }
        }
    }
}

extension MoQTVersionSpecificParameter {
    init(_ payload: inout MoQTPayload) throws {
        let type = try payload.getInt()
        let length = try payload.getInt()
        let data = try payload.getData(length)
        switch MoQTVersionSpecificType(rawValue: type) {
        case .authorizationInfo:
            key = .authorizationInfo
            value = String(data: data, encoding: .utf8)
        case .deliveryTimeout:
            key = .deliveryTimeout
            value = data
        case .maxCacheDuration:
            key = .maxCacheDuration
            value = data
        default:
            throw Error.missionSetupParameterType
        }
    }
}
