import Foundation
import XCTest

class AMF3SerializerTests: XCTestCase {
    let amf3:AMF3Serializer = AMF3Serializer()

    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func testInt() {
        var position:Int = 0
        let value:Int = 1024
        var bytes:[UInt8] = amf3.serialize(value)
        XCTAssertEqual(value, amf3.deserialize(&bytes, &position))
    }

    func testString() {
        var position:Int = 0
        let value:String = "Hello World!!"
        var bytes:[UInt8] = amf3.serialize(value)
        XCTAssertEqual(value, amf3.deserialize(&bytes, &position))
    }

    func testNumber() {
        var position:Int = 0
        let value:Double = 1024.1024
        var bytes:[UInt8] = amf3.serialize(value)
        XCTAssertEqual(value, amf3.deserialize(&bytes, &position))
    }
}
