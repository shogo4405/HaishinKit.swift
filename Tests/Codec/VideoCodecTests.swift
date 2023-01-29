import Foundation
import XCTest
import AVFoundation

@testable import HaishinKit

final class VideoCodecTests: XCTestCase {
    func testSettigs() {
        let codec = VideoCodec()
        XCTAssertEqual(codec.settings[.width] as? Int32, codec.width)
        XCTAssertEqual(codec.settings[.height] as? Int32, codec.height)
        XCTAssertEqual(codec.settings[.profileLevel] as? String, codec.profileLevel)
        XCTAssertEqual(codec.settings[.scalingMode] as? ScalingMode, codec.scalingMode)
        XCTAssertEqual(codec.settings[.maxKeyFrameIntervalDuration] as? Double, codec.maxKeyFrameIntervalDuration)
        XCTAssertEqual(codec.settings[.bitRateMode] as? VideoCodec.BitRateMode, codec.bitRateMode)

        codec.settings[.width] = Int8(100)
        XCTAssertEqual(100, codec.width)

        let cgfloatHeight: CGFloat = 200
        codec.settings[.height] = cgfloatHeight
        XCTAssertEqual(200, codec.height)

        codec.settings[.scalingMode] = ScalingMode.letterbox
        XCTAssertEqual(codec.settings[.scalingMode] as? ScalingMode, ScalingMode.letterbox)

        codec.settings[.maxKeyFrameIntervalDuration] = Float(5.0)
        XCTAssertEqual(5.0, codec.maxKeyFrameIntervalDuration)

        if #available(iOS 16.0, *) {
            codec.settings[.bitRateMode] = VideoCodec.BitRateMode.constant
            XCTAssertEqual(VideoCodec.BitRateMode.constant, codec.bitRateMode)
        }
    }
}

