import Foundation
import XCTest

@testable import HaishinKit

final class AMF0SerializerTests: XCTestCase {

    static let connectionChunk: AMFObject = [
        "tcUrl": "rtmp://localhost:1935/live",
        "flashVer": "FMLE/3.0 (compatible; FMSc/1.0)",
        "swfUrl": nil,
        "app": "live",
        "fpad": false,
        "audioCodecs": Double(1024),
        "videoCodecs": Double(128),
        "videoFunction": Double(1),
        "capabilities": Double(239),
        "fourCcList": ["av01", "vp09", "hvc1"],
        "pageUrl": nil,
        "objectEncoding": Double(0)
    ]

    func testConnectionChunk() {
        var amf: any AMFSerializer = AMF0Serializer()
        amf.serialize(AMF0SerializerTests.connectionChunk)
        amf.position = 0
        let result: AMFObject = try! amf.deserialize()
        for key in AMF0SerializerTests.connectionChunk.keys {
            let value: Any? = result[key]! as Any?
            switch key {
            case "tcUrl":
                XCTAssertEqual(value as? String, "rtmp://localhost:1935/live")
            case "flashVer":
                XCTAssertEqual(value as? String, "FMLE/3.0 (compatible; FMSc/1.0)")
            case "swfUrl":
                XCTAssertNil(value)
            case "app":
                XCTAssertEqual(value as? String, "live")
            case "fpad":
                XCTAssertEqual(value as? Bool, false)
            case "audioCodecs":
                XCTAssertEqual(value as? Double, Double(1024))
            case "videoCodecs":
                XCTAssertEqual(value as? Double, Double(128))
            case "videoFunction":
                XCTAssertEqual(value as? Double, Double(1))
            case "capabilities":
                XCTAssertEqual(value as? Double, Double(239))
            case "pageUrl":
                XCTAssertNil(value)
            case "fourCcList":
                XCTAssertEqual(value as? [String], ["av01", "vp09", "hvc1"])
            case "objectEncoding":
                XCTAssertEqual(value as? Double, Double(0))
            default:
                XCTFail(key.debugDescription)
            }
        }
    }

    func testASArray() {
        var array = AMFArray()
        array["hello"] = "world"
        array["world"] = "hello"
        var amf: any AMFSerializer = AMF0Serializer()
        amf.serialize(array)
        amf.position = 0
        let result: AMFArray = try! amf.deserialize()
        XCTAssertEqual(array["hello"] as? String, result["hello"] as? String)
        XCTAssertEqual(array["world"] as? String, result["world"] as? String)
    }
}
