import Foundation
import XCTest

@testable import HaishinKit

final class RTMPStreamTests: XCTestCase {
    func testCloseRelease() {
        let expectation = XCTestExpectation()
        weak var weakConnection: RTMPConnection?
        weak var weakStream: RTMPStream?

        _ = {
            let connection = RTMPConnection()
            let stream = RTMPStream(connection: connection)
            connection.connect("rtmp://localhost:1935/live")
            stream.play("live")

            DispatchQueue.main.async {
                connection.close()
                stream.close()
                expectation.fulfill()
            }

            weakConnection = connection
            weakStream = stream
        }()

        XCTWaiter().wait(for: [expectation], timeout: 1)
        XCTAssertNil(weakConnection)
        XCTAssertNil(weakStream)
    }
}
