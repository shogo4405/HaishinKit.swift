import Foundation
import XCTest

class AMF0SerializerTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testMain() {
    }
}

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
        let bytes:[UInt8] = amf3.serialize(value)
        XCTAssertEqual(value, amf3.deserialize(bytes, position: &position))
    }

    func testUTF8() {
        var position:Int = 0
        let value:String = "Hello World!!"
        let bytes:[UInt8] = amf3.serialize(value)
        XCTAssertEqual(value, amf3.deserialize(bytes, position: &position))
    }

    func testNumber() {
        var position:Int = 0
        let value:Double = 1024.1024
        let bytes:[UInt8] = amf3.serialize(value)
        XCTAssertEqual(value, amf3.deserialize(bytes, position: &position))
    }
}
