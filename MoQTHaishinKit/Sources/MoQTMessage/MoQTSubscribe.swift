import Foundation
import Logboard

public struct MoQTSubscribe: MoQTMessage {
    public enum GroupOrder: Int, Sendable {
        case original = 0x0
        case ascending = 0x1
        case descending = 0x2
    }

    public enum FilterType: Int, Sendable {
        case latestGroup = 0x1
        case latestObject = 0x2
        case absoluteStart = 0x3
        case absoluteRange = 0x4
    }

    public let type: MoQTMessageType = .subscribe
    public let subscribeId: Int
    public let trackAlias: Int
    public let trackNamespace: [String]
    public let trackName: String
    public let subscribePriority: Int
    public let groupOrder: GroupOrder
    public let filterType: FilterType
    public let startGroup: Int?
    public let startObject: Int?
    public let endGroup: Int?
    public let endObject: Int?
    public let subscribeParameters: [MoQTVersionSpecificParameter]

    public var payload: Data {
        get throws {
            var payload = MoQTPayload()
            payload.putInt(subscribeId)
            payload.putInt(trackAlias)
            payload.putInt(trackNamespace.count)
            for namespace in trackNamespace {
                payload.putString(namespace)
            }
            payload.putString(trackName)
            payload.putInt(subscribePriority)
            payload.putInt(groupOrder.rawValue)
            payload.putInt(filterType.rawValue)
            switch filterType {
            case .absoluteStart:
                if let startGroup {
                    payload.putInt(startGroup)
                }
                if let startObject {
                    payload.putInt(startObject)
                }
            case .absoluteRange:
                if let startGroup {
                    payload.putInt(startGroup)
                }
                if let startObject {
                    payload.putInt(startObject)
                }
                if let endGroup {
                    payload.putInt(endGroup)
                }
                if let endObject {
                    payload.putInt(endObject)
                }
            default:
                break
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

    public struct Ok: MoQTMessage {
        public let type = MoQTMessageType.subscribeOk
        public let subscribeId: Int
        public let expires: Int
        public let groupOrder: GroupOrder
        public let contentExists: Bool
        public let largestGroupId: Int?
        public let largestObjectId: Int?
        public let subscribeParameters: [MoQTVersionSpecificParameter]

        public var payload: Data {
            get throws {
                throw MoQTMessageError.notImplemented
            }
        }

        init(_ payload: inout MoQTPayload) throws {
            subscribeId = try payload.getInt()
            expires = try payload.getInt()
            if let groupOrder = GroupOrder(rawValue: try payload.getInt()) {
                self.groupOrder = groupOrder
            } else {
                throw MoQTMessageError.notImplemented
            }
            contentExists = try payload.getBool()
            largestGroupId = contentExists ? try payload.getInt() : nil
            largestObjectId = contentExists ? try payload.getInt() : nil
            var subscribeParameters: [MoQTVersionSpecificParameter] = []
            var numberOfParameters = try payload.getInt()
            for i in 0..<numberOfParameters {
                subscribeParameters.append(try .init(&payload))
            }
            self.subscribeParameters = subscribeParameters
        }
    }

    public struct Error: MoQTMessage, Swift.Error {
        public let type = MoQTMessageType.subscribeError
        public let subscribeId: Int
        public let code: Int
        public let reasonPhrase: String
        public let trackAlias: Int

        public var payload: Data {
            get throws {
                throw MoQTMessageError.notImplemented
            }
        }

        init(_ payload: inout MoQTPayload) throws {
            subscribeId = try payload.getInt()
            code = try payload.getInt()
            reasonPhrase = try payload.getString()
            trackAlias = try payload.getInt()
        }
    }
}
