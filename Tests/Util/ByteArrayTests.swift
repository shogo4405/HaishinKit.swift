import Foundation
import XCTest

@testable import HaishinKit

final class ByteArrayTests: XCTestCase {

    func testInt8() {
        let bytes: ByteArray = ByteArray()
        bytes.writeInt8(Int8.min)
        bytes.writeInt8(0)
        bytes.writeInt8(Int8.max)
        XCTAssertEqual(bytes.position, ByteArray.sizeOfInt8 * 3)
        bytes.position = 0
        XCTAssertEqual(Int8.min, try! bytes.readInt8())
        XCTAssertEqual(0, try! bytes.readInt8())
        XCTAssertEqual(Int8.max, try! bytes.readInt8())
    }

    func testUInt8() {
        let bytes: ByteArray = ByteArray()
        bytes.writeUInt8(UInt8.min)
        bytes.writeUInt8(0)
        bytes.writeUInt8(UInt8.max)
        XCTAssertEqual(bytes.position, ByteArray.sizeOfInt8 * 3)
        bytes.position = 0
        XCTAssertEqual(UInt8.min, try! bytes.readUInt8())
        XCTAssertEqual(0, try! bytes.readUInt8())
        XCTAssertEqual(UInt8.max, try! bytes.readUInt8())
    }

    func testInt16() {
        let bytes: ByteArray = ByteArray()
        bytes.writeInt16(Int16.min)
        bytes.writeInt16(0)
        bytes.writeInt16(Int16.max)
        print(bytes)
        bytes.position = 0
        XCTAssertEqual(Int16.min, try! bytes.readInt16())
        XCTAssertEqual(0, try! bytes.readInt16())
        XCTAssertEqual(Int16.max, try! bytes.readInt16())
    }

    func testUInt16() {
        let bytes: ByteArray = ByteArray()
        bytes.writeUInt16(UInt16.min)
        bytes.writeUInt16(0)
        bytes.writeUInt16(UInt16.max)
        bytes.position = 0
        XCTAssertEqual(UInt16.min, try! bytes.readUInt16())
        XCTAssertEqual(0, try! bytes.readUInt16())
        XCTAssertEqual(UInt16.max, try! bytes.readUInt16())
    }

    func testUInt24() {
        let bytes: ByteArray = ByteArray()
        bytes.writeUInt24(0xFFFFFF)
        bytes.position = 0
        XCTAssertEqual(0xFFFFFF, try! bytes.readUInt24())
    }

    func testUInt32() {
        let bytes: ByteArray = ByteArray()
        bytes.writeUInt32(UInt32.min)
        bytes.writeUInt32(0)
        bytes.writeUInt32(UInt32.max)
        bytes.position = 0
        XCTAssertEqual(UInt32.min, try! bytes.readUInt32())
        XCTAssertEqual(0, try! bytes.readUInt32())
        XCTAssertEqual(UInt32.max, try! bytes.readUInt32())
    }

    func testInt32() {
        let bytes: ByteArray = ByteArray()
        bytes.writeInt32(Int32.min)
        bytes.writeInt32(0)
        bytes.writeInt32(Int32.max)
        bytes.position = 0
        XCTAssertEqual(Int32.min, try! bytes.readInt32())
        XCTAssertEqual(0, try! bytes.readInt32())
        XCTAssertEqual(Int32.max, try! bytes.readInt32())
    }

    func testFloat() {
        let bytes: ByteArray = ByteArray()
        bytes.writeFloat(Float.infinity)
        XCTAssertEqual(bytes.position, ByteArray.sizeOfFloat)
        bytes.position = 0
        XCTAssertEqual(Float.infinity, try! bytes.readFloat())
    }

    func testDouble() {
        let bytes: ByteArray = ByteArray()
        bytes.writeDouble(.pi)
        XCTAssertEqual(bytes.position, ByteArray.sizeOfDouble)
        bytes.position = 0
        XCTAssertEqual(Double.pi, try! bytes.readDouble())
        bytes.clear()
        bytes.writeDouble(Double.infinity)
        bytes.position = 0
        XCTAssertEqual(Double.infinity, try! bytes.readDouble())
    }

    func testUTF8() {
        let bytes: ByteArray = ByteArray()
        do {
            try bytes.writeUTF8("hello world!!")
        } catch {
            XCTFail()
        }

        let length: Int = bytes.position
        bytes.position = 0
        XCTAssertEqual("hello world!!", try! bytes.readUTF8())
        bytes.position = 0

        var raiseError: Bool = false
        do {
            let _: String = try bytes.readUTF8Bytes(length + 10)
        } catch {
            raiseError = true
        }

        XCTAssertTrue(raiseError)
    }
}
