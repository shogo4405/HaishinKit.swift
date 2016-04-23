import Foundation
import XCTest

@testable import lf

final class ASStructTests: XCTestCase {
    func testASArray() {
        var array:ASArray = ASArray()
        array[5] = "hoge"
    }
}
