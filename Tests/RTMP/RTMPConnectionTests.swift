import Foundation
import XCTest

@testable import HaishinKit

final class RTMPConnectionTests: XCTestCase {
    func publish() {
        let connection: RTMPConnection = RTMPConnection()
        let stream: RTMPStream = RTMPStream(connection: connection)
        connection.connect("rtmp://localhost:1935/live")
        stream.publish("live")
        sleep(10000)
    }

    func testReleaseWhenClose() {
        weak var weakConnection: RTMPConnection?
        _ = {
            let connection = RTMPConnection()
            connection.connect("rtmp://localhost:1935/live")
            connection.close()
            weakConnection = connection
        }()
        XCTAssertNil(weakConnection)
    }
}
