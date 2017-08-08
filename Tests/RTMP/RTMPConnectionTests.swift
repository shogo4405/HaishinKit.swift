import Foundation
import XCTest

@testable import HaishinKit

final class RTMPConnectionTests: XCTestCase {
    func publish() {
        let bundle:Bundle = Bundle(for: type(of: self))
        let url:URL = URL(fileURLWithPath: bundle.path(forResource: "SampleVideo_360x240_5mb-base", ofType: "mp4")!)
        let connection:RTMPConnection = RTMPConnection()
        let stream:RTMPStream = RTMPStream(connection: connection)
        connection.connect("rtmp://localhost:1935/live")
        stream.appendFile(url)
        stream.publish("live")
        sleep(10000)
    }
}
