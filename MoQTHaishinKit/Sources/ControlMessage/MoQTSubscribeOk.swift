import Foundation

public struct MoQTSubscribeOk: MoQTControlMessage {
    public let type = MoQTMessageType.subscribeOk
    public let subscribeId: Int
    public let expires: Int
    public let groupOrder: MoQTSubscribe.GroupOrder
    public let contentExists: Bool
    public let largestGroupId: Int?
    public let largestObjectId: Int?
    public let subscribeParameters: [MoQTVersionSpecificParameter]

    public var payload: Data {
        get throws {
            var payload = MoQTPayload()
            payload.putInt(subscribeId)
            payload.putInt(expires)
            payload.putInt(groupOrder.rawValue)
            _ = payload.putBool(contentExists)
            if contentExists {
                if let largestGroupId {
                    payload.putInt(largestGroupId)
                }
                if let largestObjectId {
                    payload.putInt(largestObjectId)
                }
            }
            for parameter in subscribeParameters {
                payload.putData(try parameter.payload)
            }
            return payload.data
        }
    }
}

extension MoQTSubscribeOk {
    init(_ payload: inout MoQTPayload) throws {
        subscribeId = try payload.getInt()
        expires = try payload.getInt()
        if let groupOrder = MoQTSubscribe.GroupOrder(rawValue: try payload.getInt()) {
            self.groupOrder = groupOrder
        } else {
            throw MoQTControlMessageError.notImplemented
        }
        contentExists = try payload.getBool()
        largestGroupId = contentExists ? try payload.getInt() : nil
        largestObjectId = contentExists ? try payload.getInt() : nil
        var subscribeParameters: [MoQTVersionSpecificParameter] = []
        let numberOfParameters = try payload.getInt()
        for _ in 0..<numberOfParameters {
            subscribeParameters.append(try .init(&payload))
        }
        self.subscribeParameters = subscribeParameters
    }
}
