import Foundation
import XCTest

@testable import HaishinKit

final class AVFFormatStreamTests: XCTestCase {
    func testToVideoFormat1() {
        var data = Data([0, 0, 0, 1, 10, 10, 0, 0, 0, 1, 3, 3, 2, 0, 0, 0, 1, 5, 5, 5])
        XCTAssertEqual(AVCFormatStream.toVideoStream(&data).bytes, Data([0, 0, 0, 2, 10, 10, 0, 0, 0, 3, 3, 3, 2, 0, 0, 0, 3, 5, 5, 5]).bytes)
    }
}
