import Foundation
import Testing

@testable import HaishinKit

@Suite struct FoundationExtensionTest {
    @Test func nSURL() {
        let url = URL(string: "http://localhost/foo/bar?hello=world!!&foo=bar")!
        let dictionary: [String: String] = url.dictionaryFromQuery()
        #expect(dictionary["hello"] == "world!!")
        #expect(dictionary["foo"] == "bar")
    }
}
