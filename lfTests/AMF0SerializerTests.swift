import Foundation
import XCTest

class AMF0SerializerTests: XCTestCase {
    let amf0:AMF0Serializer = AMF0Serializer()
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testString() {
        var position:Int = 0
        let string:String = "Hello World!!"
        var bytes:[UInt8] = amf0.serialize(string)
        XCTAssertEqual(string, amf0.deserialize(&bytes, &position))
    }
}