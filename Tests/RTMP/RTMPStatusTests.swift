import Foundation
import XCTest

@testable import HaishinKit

final class RTMPStatusTests: XCTestCase {
    func testDynamicMemeberLookup() {
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
        XCTAssertEqual("world!!", status.hello)
        XCTAssertEqual(0.0, status.objectEncoding)
    }
}
