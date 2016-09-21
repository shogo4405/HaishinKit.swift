import Foundation
import XCTest

@testable import lf

final class EventDispatcherTest: XCTestCase {
    func testMain() {
        let eventDispatcher:EventDispatcher = EventDispatcher()
        eventDispatcher.addEventListener("test", selector: #selector(EventDispatcherTest.onTest(_:)), observer: self)
        eventDispatcher.dispatch(type: "type", bubbles: false, data: "Hoge")
        eventDispatcher.removeEventListener("test", selector: #selector(EventDispatcherTest.onTest(_:)), observer: self)
        eventDispatcher.dispatch(type: "test", bubbles: false, data: "Hoge")
    }

    func onTest(_ notification: Notification) {
    }
}
