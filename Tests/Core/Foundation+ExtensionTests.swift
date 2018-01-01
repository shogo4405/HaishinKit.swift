import Foundation
import XCTest

@testable import HaishinKit

final class FoundationExtensionTest: XCTestCase {
    func testNSURL() {
        let url: URL = URL(string: "http://localhost/foo/bar?hello=world!!&foo=bar")!
        let dictionary: [String: String] = url.dictionaryFromQuery()
        XCTAssertEqual(dictionary["hello"], "world!!")
        XCTAssertEqual(dictionary["foo"], "bar")
    }
}
