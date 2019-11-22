import Foundation
import XCTest

@testable import HaishinKit

final class CircularBufferTests: XCTestCase {
    func testCircularBuffer() {
        var buffer = CircularBuffer<String>(4)
        _ = buffer.append("a")
        _ = buffer.append("b")
        _ = buffer.append("c")
        _ = buffer.append("d")
        print(buffer)
        XCTAssertEqual(buffer.removeFirst(), "a")
        XCTAssertEqual(buffer.removeFirst(), "b")
        XCTAssertEqual(buffer.removeFirst(), "c")
        XCTAssertEqual(buffer.removeFirst(), "d")
        _ = buffer.append("a")
        _ = buffer.append("b")
        _ = buffer.append("c")
        _ = buffer.append("d")
        XCTAssertEqual(buffer.removeFirst(), "a")
        XCTAssertEqual(buffer.removeFirst(), "b")
        XCTAssertEqual(buffer.removeFirst(), "c")
        XCTAssertEqual(buffer.removeFirst(), "d")
        print(buffer)
    }
}
