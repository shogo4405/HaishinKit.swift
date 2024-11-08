import Foundation
import Testing

@testable import HaishinKit

@Suite struct ADTSHeaderTests {
    @Test func bytes() {
        let data = Data([255, 241, 77, 128, 112, 127, 252, 1])
        _ = ADTSHeader(data: data)
    }
}
