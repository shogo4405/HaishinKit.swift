import Foundation
import XCTest

@testable import HaishinKit

final class CircularBufferTests: XCTestCase {
    func testExtensibleCircularBuffer() {
        var buffer = CircularBuffer<String>(4, extensible: false)
        _ = buffer.append("a")
        _ = buffer.append("b")
        _ = buffer.append("c")
        _ = buffer.append("d")
        XCTAssertEqual(buffer.count, 4)
        XCTAssertEqual(buffer.isFull, true)
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

    func testNonExtensibleCircularBuffer() {
        var buffer = CircularBuffer<String>(4, extensible: true)
        _ = buffer.append("a")
        _ = buffer.append("b")
        _ = buffer.append("c")
        _ = buffer.append("d")
        XCTAssertEqual(buffer.count, 4)
        XCTAssertEqual(buffer.isFull, true)
        print(buffer)
        XCTAssertEqual(buffer.removeFirst(), "a")
        XCTAssertEqual(buffer.removeFirst(), "b")
        XCTAssertEqual(buffer.removeFirst(), "c")
        XCTAssertEqual(buffer.removeFirst(), "d")
        XCTAssertEqual(buffer.count, 0)
        XCTAssertEqual(buffer.isEmpty, true)
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
