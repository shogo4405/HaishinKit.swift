import Foundation
import XCTest

@testable import lf

class AMF3SerializerTests: XCTestCase {
    func testBool() {
        let amf:AMF3Serializer = AMF3Serializer()
        amf.serialize(true)
        amf.serialize(false)
        amf.position = 0
        XCTAssertTrue(try! amf.deserialize())
        XCTAssertFalse(try! amf.deserialize())
    }
}

