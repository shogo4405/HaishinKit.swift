import Foundation
import XCTest

@testable import HaishinKit

final class EventDispatcherTest: XCTestCase {
    func testMain() {
        let eventDispatcher:EventDispatcher = EventDispatcher()
        eventDispatcher.addEventListener("test", selector: #selector(EventDispatcherTest.onTest(_:)), observer: self)
        eventDispatcher.dispatch("type", bubbles: false, data: "Hoge")
        eventDispatcher.removeEventListener("test", selector: #selector(EventDispatcherTest.onTest(_:)), observer: self)
        eventDispatcher.dispatch("test", bubbles: false, data: "Hoge")
    }

    func onTest(_ notification: Notification) {
    }
}
