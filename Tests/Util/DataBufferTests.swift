import Foundation
import XCTest

@testable import HaishinKit

final class NetSocketCycleBufferTests: XCTestCase {
    func testAppendAndTest() {
        let buffer = DataBuffer(capacity: 1024)
        XCTAssertTrue(buffer.append(Data(repeating: 1, count: 512)))
        XCTAssertEqual(buffer.maxLength, 512)
        XCTAssertTrue(buffer.append(Data(repeating: 2, count: 512)))
        XCTAssertEqual(buffer.maxLength, 1024)
        XCTAssertTrue(buffer.append(Data(repeating: 3, count: 512)))
        XCTAssertEqual(buffer.capacity, 1024 * 2)
        XCTAssertTrue(buffer.append(Data(repeating: 4, count: 1024)))
        XCTAssertEqual(buffer.capacity, 1024 * 3)
    }
}
