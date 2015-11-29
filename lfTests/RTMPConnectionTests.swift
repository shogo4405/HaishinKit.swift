import Foundation
import XCTest

class RTMPConnectionTests: XCTestCase {

    let url:String = "rtmp://localhost/"
    let streamName:String = "test"

    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func testPlay() {
        /*
        let rtmpConnection:RTMPConnection = RTMPConnection()
        let rtmpStream:RTMPStream = RTMPStream(rtmpConnection: rtmpConnection)
        rtmpConnection.connect(url)
        sleep(2)
        rtmpStream.play(streamName)
        
        println("--------")
        while (true) {
            sleep(1)
        }
        */
    }

    func testSharedObject() {
        let rtmpConnection:RTMPConnection = RTMPConnection()
        let sharedObject:RTMPSharedObject = RTMPSharedObject.getRemote("shared/liveSessions", remotePath: url, persistence: false)
        rtmpConnection.connect(url)
        sharedObject.connect(rtmpConnection)

        while (true) {
            sleep(1)
        }
    }
}
