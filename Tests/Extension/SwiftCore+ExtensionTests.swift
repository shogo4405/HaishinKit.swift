import Foundation
import Testing

@testable import HaishinKit

@Suite struct SwiftCoreExtensionTests {
    @Test func int32() {
        #expect(Int32.min == Int32(data: Int32.min.data))
        #expect(Int32.max == Int32(data: Int32.max.data))
    }
}
