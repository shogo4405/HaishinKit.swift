import Foundation
import XCTest

@testable import lf

final class AudioUtilTests: XCTestCase {
    func testGetVolume() {
        print(AudioSessionUtil.getVolume())
    }
}
