import Foundation
import Testing

@testable import HaishinKit

@Suite struct AMF0SerializerTests {
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

    @Test func connectionChunk() throws {
        var amf: any AMFSerializer = AMF0Serializer()
        amf.serialize(AMF0SerializerTests.connectionChunk)
        amf.position = 0
        let result: AMFObject = try amf.deserialize()
        for key in AMF0SerializerTests.connectionChunk.keys {
            let value: Any? = result[key]! as Any?
            switch key {
            case "tcUrl":
                #expect(value as? String == "rtmp://localhost:1935/live")
            case "flashVer":
                #expect(value as? String == "FMLE/3.0 (compatible; FMSc/1.0)")
            case "swfUrl":
                #expect(value == nil)
            case "app":
                #expect(value as? String == "live")
            case "fpad":
                #expect(value as? Bool == false)
            case "audioCodecs":
                #expect(value as? Double == Double(1024))
            case "videoCodecs":
                #expect(value as? Double == Double(128))
            case "videoFunction":
                #expect(value as? Double == Double(1))
            case "capabilities":
                #expect(value as? Double == Double(239))
            case "pageUrl":
                #expect(value == nil)
            case "fourCcList":
                #expect(value as? [String] == ["av01", "vp09", "hvc1"])
            case "objectEncoding":
                #expect(value as? Double == Double(0))
            default:
                Issue.record(key.debugDescription as! (any Error))
            }
        }
    }

    @Test func asarray() throws {
        var array = AMFArray()
        array["hello"] = "world"
        array["world"] = "hello"
        var amf: any AMFSerializer = AMF0Serializer()
        amf.serialize(array)
        amf.position = 0
        let result: AMFArray = try amf.deserialize()
        #expect(array["hello"] as? String == result["hello"] as? String)
        #expect(array["world"] as? String == result["world"] as? String)
    }
}
