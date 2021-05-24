import Foundation
import XCTest

@testable import HaishinKit

final class BaseDescriptorTests: XCTestCase {
    func testDecoderSpecificInfo() {
        var src = DecoderSpecificInfo()
        src.data = Data([5, 128, 128, 128, 2, 17, 176])

        var dst = DecoderSpecificInfo()
        dst.data = src.data
        XCTAssertEqual(src, dst)
    }

    func testSLConfigDescriptor() {
        var src = SLConfigDescriptor()
        src.data = Data([6, 128, 128, 128, 1, 2])

        var dst = SLConfigDescriptor()
        dst.data = src.data
        XCTAssertEqual(src, dst)
    }
}
