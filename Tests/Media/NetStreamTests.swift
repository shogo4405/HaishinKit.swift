import Foundation
import XCTest

@testable import HaishinKit

final class NetStreamTests: XCTestCase {
    func testVideoSettings() {
        let stream = NetStream()
        stream.videoSettings = [
            .profileLevel: "H264_Main_AudoLevel",
            .bitrate: 3000 * 0000,
            .width: 700,
            .height: 1400
        ]
        XCTAssertEqual("H264_Main_AudoLevel", stream.videoSettings[.profileLevel] as? String)
        XCTAssertEqual(3000 * 0000, stream.videoSettings[.bitrate] as? UInt32)
        XCTAssertEqual(700, stream.videoSettings[.width] as? Int32)
        XCTAssertEqual(1400, stream.videoSettings[.height] as? Int32)
    }
}
