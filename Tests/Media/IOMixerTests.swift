import Foundation
import XCTest

@testable import HaishinKit

final class IOMixerTests: XCTestCase {
    func testRelease() {
        weak var weakIOMixer: IOMixer?
        _ = {
            let mixer = IOMixer()
            mixer.audioIO.codec.settings.bitRate = 100000
            mixer.videoIO.codec.settings.bitRate = 100000
            weakIOMixer = mixer
        }()
        XCTAssertNil(weakIOMixer)
    }
}
