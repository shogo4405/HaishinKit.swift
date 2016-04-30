import Foundation
import XCTest

@testable import lf

final class EventDispatcherTest: XCTestCase {
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
