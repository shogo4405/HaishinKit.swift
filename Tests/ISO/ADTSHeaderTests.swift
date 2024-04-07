import Foundation
import XCTest

@testable import HaishinKit

final class ADTSHeaderTests: XCTestCase {
    func testBytes() {
        let data = Data([255, 241, 77, 128, 112, 127, 252, 1])
        let header = ADTSHeader(data: data)
    }
}
