import Foundation

public enum MoQTSetupParameterType: Int, Sendable {
    case role = 0x00
    case path = 0x01
    case maxSubscribeId = 0x02
}

public enum MoQTSetupRole: Int, Sendable {
    case publisher = 0x01
    case subscriber = 0x02
    case pubSub = 0x03
}

public struct MoQTSetupParameter: Sendable {
    enum Error: Swift.Error {
        case missionSetupParameterType
    }

    public let key: MoQTSetupParameterType
    public let value: (any Sendable)

    var payload: Data {
        get throws {
            switch value {
            case let value as String:
                var payload = MoQTPayload()
                payload.putInt(key.rawValue)
                payload.putString(value)
                return payload.data
            case let value as MoQTSetupRole:
                var payload = MoQTPayload()
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

extension MoQTSetupParameter {
    init(_ payload: inout MoQTPayload) throws {
        let type = try payload.getInt()
        let length = try payload.getInt()

        switch MoQTSetupParameterType(rawValue: type) {
        case .path:
            key = .path
            let data = try payload.getData(length)
            value = String(data: data, encoding: .utf8)
        case .role:
            key = .role
            value = try payload.getInt()
        case .maxSubscribeId:
            key = .maxSubscribeId
            value = try payload.getInt()
        default:
            throw Error.missionSetupParameterType
        }
    }
}
