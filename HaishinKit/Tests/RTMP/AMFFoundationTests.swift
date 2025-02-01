import Foundation
import Testing

@testable import HaishinKit

@Suite struct AMFFoundationTests {
    static let hello: String = "<a>hello</a>"

    @Test func array() {
        var array = AMFArray()
        array[5] = "hoge"
        if let array_5: String = array[5] as? String {
            #expect(array_5 == "hoge")
        }
    }

    @Test func xmlDocument() {
        let xml = AMFXMLDocument(data: AMFFoundationTests.hello)
        #expect(xml.description == AMFFoundationTests.hello)
    }

    @Test func xml() {
        let xml = AMFXML(data: AMFFoundationTests.hello)
        #expect(xml.description == AMFFoundationTests.hello)
    }
}
