import Foundation
import XCTest

@testable import HaishinKit

final class ExpressibleByIntegerLiteralTests: XCTestCase {
    func testInt32() {
        XCTAssertEqual(Int32.min.bigEndian.data, Data([128, 0, 0, 0]))
        XCTAssertEqual(Int32(32).bigEndian.data, Data([0, 0, 0, 32]))
        XCTAssertEqual(Int32.max.bigEndian.data, Data([127, 255, 255, 255]))
    }

    func testUInt32() {
        XCTAssertEqual(UInt32.min.bigEndian.data, Data([0, 0, 0, 0]))
        XCTAssertEqual(UInt32(32).bigEndian.data, Data([0, 0, 0, 32]))
        XCTAssertEqual(UInt32.max.bigEndian.data, Data([255, 255, 255, 255]))
    }
    
    func testInt64() {
        XCTAssertEqual(Int64.min.bigEndian.data, Data([128, 0, 0, 0, 0, 0, 0, 0]))
        XCTAssertEqual(Int64(32).bigEndian.data, Data([0, 0, 0, 0, 0, 0, 0, 32]))
        XCTAssertEqual(Int64.max.bigEndian.data, Data([127,255,255, 255, 255, 255, 255, 255]))
    }

    func testUInt64() {
        XCTAssertEqual(UInt64.min.bigEndian.data, Data([0, 0, 0, 0, 0, 0, 0, 0]))
        XCTAssertEqual(UInt64(32).bigEndian.data, Data([0, 0, 0, 0, 0, 0, 0, 32]))
        XCTAssertEqual(UInt64.max.bigEndian.data, Data([255, 255, 255, 255, 255, 255, 255, 255]))
    }
}
