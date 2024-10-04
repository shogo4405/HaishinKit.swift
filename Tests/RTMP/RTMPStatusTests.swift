import Foundation
import Testing

@testable import HaishinKit

@Suite struct RTMPStatusTests {
    @Test func dynamicMemeberLookup() {
        let data: AMFObject = [
            "level": "status",
            "code": "NetConnection.Connect.Success",
            "description": "Connection succeeded.",
            "objectEncoding": 0.0,
            "hello": "world!!"
        ]
        guard let status = RTMPStatus(data) else {
            return
        }
        #expect("world!!" == status.hello)
        #expect(0.0 == status.objectEncoding)
    }
}
