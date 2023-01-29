import Foundation
import XCTest
import AVFoundation

@testable import HaishinKit

final class SettingTests: XCTestCase {
    func testH264Encoder() {
        let encoder = VideoCodec()
        XCTAssertEqual(encoder.settings[.width] as? Int32, encoder.width)
        XCTAssertEqual(encoder.settings[.height] as? Int32, encoder.height)
        XCTAssertEqual(encoder.settings[.profileLevel] as? String, encoder.profileLevel)
        XCTAssertEqual(encoder.settings[.scalingMode] as? ScalingMode, encoder.scalingMode)
        XCTAssertEqual(encoder.settings[.maxKeyFrameIntervalDuration] as? Double, encoder.maxKeyFrameIntervalDuration)

        encoder.settings[.width] = Int8(100)
        XCTAssertEqual(100, encoder.width)
        
        let cgfloatHeight: CGFloat = 200
        encoder.settings[.height] = cgfloatHeight
        XCTAssertEqual(200, encoder.height)

        encoder.settings[.scalingMode] = ScalingMode.letterbox
        XCTAssertEqual(encoder.settings[.scalingMode] as? ScalingMode, ScalingMode.letterbox)

        encoder.settings[.maxKeyFrameIntervalDuration] = Float(5.0)
        XCTAssertEqual(5.0, encoder.maxKeyFrameIntervalDuration)
    }
}
