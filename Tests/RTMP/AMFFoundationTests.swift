import Foundation
import XCTest

@testable import HaishinKit

final class AMFFoundationTests: XCTestCase {

    static let hello: String = "<a>hello</a>"

    func testASArray() {
        var array = AMFArray()
        array[5] = "hoge"
        if let array_5: String = array[5] as? String {
            XCTAssertEqual(array_5, "hoge")
        }
    }

    func testASXMLDocument() {
        let xml = AMFXMLDocument(data: AMFFoundationTests.hello)
        XCTAssertEqual(xml.description, AMFFoundationTests.hello)
    }

    func testASXML() {
        let xml = AMFXML(data: AMFFoundationTests.hello)
        XCTAssertEqual(xml.description, AMFFoundationTests.hello)
    }
}
