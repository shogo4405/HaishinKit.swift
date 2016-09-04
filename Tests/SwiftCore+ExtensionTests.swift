import Foundation
import XCTest

@testable import lf

final class SwiftCoreExtensionTests: XCTestCase {
    
    func testInt32() {
        XCTAssertEqual(Int32.min, Int32(bytes: Int32.min.bytes))
        XCTAssertEqual(Int32.max, Int32(bytes: Int32.max.bytes))
    }

    func testArraySplit() {
        let data:[UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 2, 8, 9]

        let result:[[UInt8]] = data.split(by: 3)
        let answer:[[UInt8]] = [[0, 1, 2], [3, 4, 5], [6, 7, 2], [8, 9]]
        for i in 0..<result.count {
            XCTAssertEqual(result[i], answer[i])
        }
    }
}
