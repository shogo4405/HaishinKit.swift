import Foundation
import Logboard

public struct MoQTSubscribe: MoQTControlMessage {
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
}

extension MoQTSubscribe {
    init(_ payload: inout MoQTPayload) throws {
        subscribeId = try payload.getInt()
        trackAlias = try payload.getInt()
        var trackNamespace: [String] = []
        for _ in 0..<(try payload.getInt()) {
            trackNamespace.append(try payload.getString())
        }
        self.trackNamespace = trackNamespace
        trackName = try payload.getString()
        subscribePriority = try payload.getInt()
        groupOrder = GroupOrder(rawValue: try payload.getInt()) ?? .original
        filterType = FilterType(rawValue: try payload.getInt()) ?? .absoluteRange
        switch filterType {
        case .latestGroup:
            startGroup = nil
            startObject = nil
            endGroup = nil
            endObject = nil
        case .latestObject:
            startGroup = nil
            startObject = nil
            endGroup = nil
            endObject = nil
        case .absoluteStart:
            startGroup = try payload.getInt()
            startObject = try payload.getInt()
            endGroup = nil
            endObject = nil
        case .absoluteRange:
            startGroup = try payload.getInt()
            startObject = try payload.getInt()
            endGroup = try payload.getInt()
            endObject = try payload.getInt()
        }
        var subscribeParameters: [MoQTVersionSpecificParameter] = []
        for _ in 0..<(try payload.getInt()) {
            subscribeParameters.append(try .init(&payload))
        }
        self.subscribeParameters = subscribeParameters
    }
}
