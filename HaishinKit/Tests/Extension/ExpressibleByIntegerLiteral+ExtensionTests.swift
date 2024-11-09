import Foundation
import Testing

@testable import HaishinKit

@Suite struct ExpressibleByIntegerLiteralTests {
    @Test func int32() {
        #expect(Int32.min.bigEndian.data == Data([128, 0, 0, 0]))
        #expect(Int32(32).bigEndian.data == Data([0, 0, 0, 32]))
        #expect(Int32.max.bigEndian.data == Data([127, 255, 255, 255]))
    }

    @Test func uInt32() {
        #expect(UInt32.min.bigEndian.data == Data([0, 0, 0, 0]))
        #expect(UInt32(32).bigEndian.data == Data([0, 0, 0, 32]))
        #expect(UInt32.max.bigEndian.data == Data([255, 255, 255, 255]))
    }

    @Test func int64() {
        #expect(Int64.min.bigEndian.data == Data([128, 0, 0, 0, 0, 0, 0, 0]))
        #expect(Int64(32).bigEndian.data == Data([0, 0, 0, 0, 0, 0, 0, 32]))
        #expect(Int64.max.bigEndian.data == Data([127, 255, 255, 255, 255, 255, 255, 255]))
    }

    @Test func uInt64() {
        #expect(UInt64.min.bigEndian.data == Data([0, 0, 0, 0, 0, 0, 0, 0]))
        #expect(UInt64(32).bigEndian.data == Data([0, 0, 0, 0, 0, 0, 0, 32]))
        #expect(UInt64.max.bigEndian.data == Data([255, 255, 255, 255, 255, 255, 255, 255]))
    }
}
