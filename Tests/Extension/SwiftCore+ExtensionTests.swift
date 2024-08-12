import Foundation
import XCTest

@testable import HaishinKit

final class SwiftCoreExtensionTests: XCTestCase {
    func testInt32() {
        XCTAssertEqual(Int32.min, Int32(data: Int32.min.data))
        XCTAssertEqual(Int32.max, Int32(data: Int32.max.data))
    }
}
