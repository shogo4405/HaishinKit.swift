import Foundation
import XCTest

@testable import HaishinKit

final class IOMixerTests: XCTestCase {
    func testRelease() {
        weak var weakIOMixer: IOMixer?
        _ = {
            let mixer = IOMixer()
            mixer.audioIO.codec.bitrate = 1000
            mixer.videoIO.codec.bitrate = 1000
            weakIOMixer = mixer
        }()
        XCTAssertNil(weakIOMixer)
    }
}
