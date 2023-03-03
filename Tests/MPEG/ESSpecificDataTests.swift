import Foundation
import CoreMedia
import XCTest

@testable import HaishinKit

final class ESSpecificDataTests: XCTestCase {
    private let aacData = Data([15, 225, 1, 240, 6, 10, 4, 117, 110, 100, 0])
    private let h264Data = Data([27, 225, 0, 240, 0, 15, 225, 1, 240, 6, 10, 4, 117, 110, 100, 0])

    func testAACData() {
        let data = ESSpecificData(aacData)
        XCTAssertEqual(data?.streamType, .adtsAac)
        XCTAssertEqual(data?.elementaryPID, 257)
    }

    func testH264Data() {
        let data = ESSpecificData(h264Data)
        XCTAssertEqual(data?.streamType, .h264)
        XCTAssertEqual(data?.elementaryPID, 256)
    }
}
