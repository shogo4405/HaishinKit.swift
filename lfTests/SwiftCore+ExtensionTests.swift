import Foundation
import XCTest

@testable import lf

class SwiftCoreExtensionTests: XCTestCase {
    
    func testInt32() {
        XCTAssertEqual(Int32.min, Int32(bytes: Int32.min.bytes))
        XCTAssertEqual(Int32.max, Int32(bytes: Int32.max.bytes))
    }
}
