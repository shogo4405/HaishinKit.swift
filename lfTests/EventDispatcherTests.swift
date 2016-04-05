import Foundation
import XCTest

@testable import lf

class EventDispatcherTest: XCTestCase {
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func testMain() {
        let eventDispatcher:EventDispatcher = EventDispatcher()
        eventDispatcher.addEventListener("test", selector: #selector(EventDispatcherTest.onTest(_:)), observer: self)
        eventDispatcher.dispatchEventWith("test", bubbles: false, data: "Hoge")
        eventDispatcher.removeEventListener("test", selector: #selector(EventDispatcherTest.onTest(_:)), observer: self)
        eventDispatcher.dispatchEventWith("test", bubbles: false, data: "Hoge")
    }

    func onTest(notification: NSNotification) {
        if let info = notification.userInfo as? Dictionary<String, AnyObject> {
            print(info["event"]!)
        }
    }
}
