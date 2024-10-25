import Foundation

public struct MoQTObject {
    public let id: Int
    public let status: Int?
    public let data: Data

    var payload: Data {
        get throws {
            var payload = MoQTPayload()
            payload.putInt(id)
            payload.putInt(data.count)
            if let status {
                payload.putInt(status)
            }
            payload.putData(data)
            return payload.data
        }
    }

    public init(id: Int, status: Int?, data: Data) {
        self.id = id
        self.status = status
        self.data = data
    }

    init(_ payload: inout MoQTPayload) throws {
        id = try payload.getInt()
        let length = try payload.getInt()
        status = length == 0 ? try payload.getInt() : nil
        self.data = try payload.getData(length)
    }
}
