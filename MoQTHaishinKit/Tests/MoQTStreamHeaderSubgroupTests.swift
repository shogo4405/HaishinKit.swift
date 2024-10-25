import Foundation
@testable import MoQTHaishinKit
import Testing

@Suite struct MoQTStreamHeaderSubgroupTests {
    @Test func parse() throws {
        var payload = MoQTPayload()
        payload.putData(Data([4, 64, 99, 0, 129, 184, 103, 39, 0, 0, 0, 17, 50, 48, 50, 52, 45, 49, 49, 45, 49, 54, 32, 49, 52, 58, 50, 55, 58, 1, 1, 48, 2, 1, 49, 3, 1, 50, 4, 1, 51, 5, 1, 52, 6, 1, 53, 7, 1, 54, 8, 1, 55, 9, 1, 56, 10, 1, 57, 11, 2, 49, 48, 12, 2, 49, 49, 13, 2, 49, 50, 14, 2, 49, 51, 15, 2, 49, 52, 16, 2, 49, 53, 17, 2, 49, 54, 18, 2, 49, 55, 19, 2, 49, 56, 20, 2, 49, 57, 21, 2, 50, 48, 22, 2, 50, 49, 23, 2, 50, 50, 24, 2, 50, 51, 25, 2, 50, 52, 26, 2, 50, 53, 27, 2, 50, 54, 28, 2, 50, 55, 29, 2, 50, 56, 30, 2, 50, 57, 31, 2, 51, 48, 32, 2, 51, 49, 33, 2, 51, 50, 34, 2, 51, 51, 35, 2, 51, 52, 36, 2, 51, 53, 37, 2, 51, 54, 38, 2, 51, 55, 39, 2, 51, 56, 40, 2, 51, 57, 41, 2, 52, 48, 42, 2, 52, 49, 43, 2, 52, 50, 44, 2, 52, 51, 45, 2, 52, 52, 46, 2, 52, 53, 47, 2, 52, 54, 48, 2, 52, 55, 49, 2, 52, 56, 50, 2, 52, 57, 51, 2, 53, 48]))
        payload.position = 1
        let message = try MoQTStreamHeaderSubgroup(&payload)
        #expect(message.trackAlias == 99)
        #expect(message.groupId == 0)
        var objects: [MoQTObject] = .init()
        while 0 < payload.bytesAvailable {
            objects.append(try MoQTObject(&payload))
        }
        #expect(objects.last?.id == 51)
    }
}
