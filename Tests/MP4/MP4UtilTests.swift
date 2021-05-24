import Foundation
import XCTest

@testable import HaishinKit

final class MP4UtilTests: XCTestCase {
    func testString() {
        XCTAssertEqual("msdh", MP4Util.string(1836278888))
    }

    func testUInt32() {
        XCTAssertEqual(1836278888, MP4Util.uint32("msdh"))
    }
}

