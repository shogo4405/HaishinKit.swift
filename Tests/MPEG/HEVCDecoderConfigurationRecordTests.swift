import Foundation
import AVFoundation
import XCTest

@testable import HaishinKit

final class HEVCDecoderConfigurationRecordTests: XCTestCase {
    func testMain() {
        let data = Data([1, 1, 96, 0, 0, 0, 176, 0, 0, 0, 0, 0, 93, 240, 0, 252, 253, 248, 248, 0, 0, 15, 3, 32, 0, 1, 0, 24, 64, 1, 12, 1, 255, 255, 1, 96, 0, 0, 3, 0, 176, 0, 0, 3, 0, 0, 3, 0, 93, 21, 192, 144, 33, 0, 1, 0, 36, 66, 1, 1, 1, 96, 0, 0, 3, 0, 176, 0, 0, 3, 0, 0, 3, 0, 93, 160, 2, 40, 128, 39, 28, 178, 226, 5, 123, 145, 101, 83, 80, 16, 16, 16, 8, 34, 0, 1, 0, 7, 68, 1, 192, 44, 188, 20, 201])
        let hevc = HEVCDecoderConfigurationRecord(data: data)
        var formatDescription: CMFormatDescription?
        _ = hevc.makeFormatDescription(&formatDescription)
        XCTAssertNotNil(formatDescription)
    }
}
