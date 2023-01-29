import Foundation
import XCTest

@testable import HaishinKit

final class AMFFoundationTests: XCTestCase {

    static let hello: String = "<a>hello</a>"

    func testASArray() {
        var array = ASArray()
        array[5] = "hoge"
        if let array_0: ASUndefined = array[0] as? ASUndefined {
            // XCTAssertEqual(array_0, kASUndefined)
        }
        if let array_5: String = array[5] as? String {
            XCTAssertEqual(array_5, "hoge")
        }
    }

    func testASXMLDocument() {
        let xml = ASXMLDocument(data: AMFFoundationTests.hello)
        XCTAssertEqual(xml.description, AMFFoundationTests.hello)
    }

    func testASXML() {
        let xml = ASXML(data: AMFFoundationTests.hello)
        XCTAssertEqual(xml.description, AMFFoundationTests.hello)
    }
}
