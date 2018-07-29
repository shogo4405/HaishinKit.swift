import Foundation
import XCTest

@testable import HaishinKit

final class AMF0SerializerTests: XCTestCase {

    static let connectionChunk: ASObject = [
        "tcUrl": "rtmp://localhost:1935/live",
        "flashVer": "FMLE/3.0 (compatible; FMSc/1.0)",
        "swfUrl": nil,
        "app": "live",
        "fpad": false,
        "audioCodecs": Double(1024),
        "videoCodecs": Double(128),
        "videoFunction": Double(1),
        "capabilities": Double(239),
        "pageUrl": nil,
        "objectEncoding": Double(0)
    ]

    func testConnectionChunk() {
        var amf: AMFSerializer = AMF0Serializer()
        amf.serialize(AMF0SerializerTests.connectionChunk)
        amf.position = 0
        let result: ASObject = try! amf.deserialize()
        for key in AMF0SerializerTests.connectionChunk.keys {
            let value: Any? = result[key]! as Any?
            switch key {
            case "tcUrl":
                XCTAssertEqual(value as? String, "rtmp://localhost:1935/live")
            case "flashVer":
                XCTAssertEqual(value as? String, "FMLE/3.0 (compatible; FMSc/1.0)")
            case "swfUrl":
                //XCTAssertNil(value!)
                break
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
                //XCTAssertNil(value!)
                break
            case "objectEncoding":
                XCTAssertEqual(value as? Double, Double(0))
            default:
                XCTFail(key.debugDescription)
            }
        }
    }
}
