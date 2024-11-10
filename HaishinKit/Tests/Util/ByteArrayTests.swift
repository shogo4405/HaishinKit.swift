import Foundation
import Testing

@testable import HaishinKit

@Suite struct ByteArrayTests {
    @Test func int8() throws {
        let bytes = ByteArray()
        bytes.writeInt8(Int8.min)
        bytes.writeInt8(0)
        bytes.writeInt8(Int8.max)
        #expect(bytes.position == ByteArray.sizeOfInt8 * 3)
        bytes.position = 0
        #expect(try bytes.readInt8() == Int8.min)
        #expect(try bytes.readInt8() == 0 )
        #expect(try bytes.readInt8() == Int8.max)
    }

    @Test func uint8() throws {
        let bytes = ByteArray()
        bytes.writeUInt8(UInt8.min)
        bytes.writeUInt8(0)
        bytes.writeUInt8(UInt8.max)
        #expect(bytes.position == ByteArray.sizeOfInt8 * 3)
        bytes.position = 0
        #expect(try bytes.readUInt8() == UInt8.min)
        #expect(try bytes.readUInt8() == 0)
        #expect(try bytes.readUInt8() == UInt8.max)
    }

    @Test func int16() throws {
        let bytes = ByteArray()
        bytes.writeInt16(Int16.min)
        bytes.writeInt16(0)
        bytes.writeInt16(Int16.max)
        print(bytes)
        bytes.position = 0
        #expect(try bytes.readInt16() == Int16.min)
        #expect(try bytes.readInt16() == 0)
        #expect(try bytes.readInt16() == Int16.max)
    }

    @Test func uint16() throws {
        let bytes = ByteArray()
        bytes.writeUInt16(UInt16.min)
        bytes.writeUInt16(0)
        bytes.writeUInt16(UInt16.max)
        bytes.position = 0
        #expect(try bytes.readUInt16() == UInt16.min)
        #expect(try bytes.readUInt16() == 0)
        #expect(try bytes.readUInt16() == UInt16.max)
    }

    @Test func uint24() throws {
        let bytes = ByteArray()
        bytes.writeUInt24(0xFFFFFF)
        bytes.position = 0
        #expect(try bytes.readUInt24() == 0xFFFFFF)
    }

    @Test func uint32() throws {
        let bytes = ByteArray()
        bytes.writeUInt32(UInt32.min)
        bytes.writeUInt32(0)
        bytes.writeUInt32(UInt32.max)
        bytes.position = 0
        #expect(try bytes.readUInt32() == UInt32.min)
        #expect(try bytes.readUInt32() == 0)
        #expect(try bytes.readUInt32() == UInt32.max)
    }

    @Test func int32() throws {
        let bytes = ByteArray()
        bytes.writeInt32(Int32.min)
        bytes.writeInt32(0)
        bytes.writeInt32(Int32.max)
        bytes.position = 0
        #expect(try bytes.readInt32() == Int32.min)
        #expect(try bytes.readInt32() == 0)
        #expect(try bytes.readInt32() == Int32.max)
    }

    @Test func float() throws {
        let bytes = ByteArray()
        bytes.writeFloat(Float.infinity)
        #expect(bytes.position == ByteArray.sizeOfFloat)
        bytes.position = 0
        #expect(try bytes.readFloat() == Float.infinity)
    }

    @Test func double() throws {
        let bytes = ByteArray()
        bytes.writeDouble(.pi)
        #expect(bytes.position == ByteArray.sizeOfDouble)
        bytes.position = 0
        #expect(try bytes.readDouble() == Double.pi)
        bytes.clear()
        bytes.writeDouble(Double.infinity)
        bytes.position = 0
        #expect(try bytes.readDouble() == Double.infinity)
    }

    @Test func utf8() throws {
        let bytes = ByteArray()
        do {
            try bytes.writeUTF8("hello world!!")
        } catch {
            Issue.record()
        }

        let length: Int = bytes.position
        bytes.position = 0
        #expect(try bytes.readUTF8() == "hello world!!")
        bytes.position = 0

        var raiseError = false
        do {
            let _: String = try bytes.readUTF8Bytes(length + 10)
        } catch {
            raiseError = true
        }

        #expect(raiseError)
    }
}
