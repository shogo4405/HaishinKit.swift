import Foundation
import XCTest

@testable import lf

final class SwiftCoreExtensionTests: XCTestCase {
    func testInt32() {
        XCTAssertEqual(Int32.min, Int32(bytes: Int32.min.bytes))
        XCTAssertEqual(Int32.max, Int32(bytes: Int32.max.bytes))
        XCTAssertEqual(Int32.max, Int32(data: Int32.max.data))
        
        
        print(Int32.max)
        
        print(Int32(data: Int32.max.data[0..<3]))
    }
}
