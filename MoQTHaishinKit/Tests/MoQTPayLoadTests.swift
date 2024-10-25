import Foundation
@testable import MoQTHaishinKit
import Testing

@Suite struct MoQTPayLoadTests {
    @Test func putInt() throws {
        var payload = MoQTPayload()
        payload.putInt(MoQTVersion.draft04.rawValue)
        #expect(payload.data == Data([192, 0, 0, 0, 255, 0, 0, 4]))
        payload.position = 0
        #expect(try payload.getInt() == MoQTVersion.draft04.rawValue)
        #expect(payload.position == 8)
    }
}
