import Foundation
import XCTest

@testable import lf

final class FoundationExtensionTest: XCTestCase {
    func testNSURL() {
        let url:NSURL = NSURL(string: "http://localhost/foo/bar?hello=world!!&foo=bar")!
        let dictionary:[String:AnyObject] = url.dictionaryFromQuery()
        XCTAssertEqual(dictionary["hello"] as? String, "world!!")
        XCTAssertEqual(dictionary["foo"] as? String, "bar")
    }
}
