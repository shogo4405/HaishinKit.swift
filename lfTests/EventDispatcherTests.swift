import Foundation
import XCTest

class EventDispatcherTest: XCTestCase {
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func testMain() {
        let eventDispatcher:EventDispatcher = EventDispatcher()
        eventDispatcher.addEventListener("test", selector: "onTest:", observer: self)
        eventDispatcher.dispatchEventWith("test", bubbles: false, data: "Hoge")
        eventDispatcher.removeEventListener("test", selector: "onTest:", observer: self)
        eventDispatcher.dispatchEventWith("test", bubbles: false, data: "Hoge")
    }

    func onTest(notification: NSNotification) {
        if let info = notification.userInfo as? Dictionary<String, AnyObject> {
            println(info["event"]!)
        }
    }
}
