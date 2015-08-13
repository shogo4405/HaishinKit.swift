import Foundation
import XCTest

class RTMPConnectionTests: XCTestCase {

    let url:String = "rtmp://192.168.179.4/live"
    let streamName:String = "test"

    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func testPlay() {
        let rtmpConnection:RTMPConnection = RTMPConnection()
        let rtmpStream:RTMPStream = RTMPStream(rtmpConnection: rtmpConnection)
        rtmpConnection.connect(url)
        sleep(2)
        rtmpStream.play(streamName)
        
        println("--------")
        while (true) {
            sleep(1)
        }
    }
}
