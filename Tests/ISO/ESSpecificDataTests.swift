import Foundation
import CoreMedia
import Testing

@testable import HaishinKit

@Suite struct ESSpecificDataTests {
    private let aacData = Data([15, 225, 1, 240, 6, 10, 4, 117, 110, 100, 0])
    private let h264Data = Data([27, 225, 0, 240, 0, 15, 225, 1, 240, 6, 10, 4, 117, 110, 100, 0])

    @Test func aACData() {
        let data = ESSpecificData(aacData)
        #expect(data?.streamType == .adtsAac)
        #expect(data?.elementaryPID == 257)
    }

    @Test func testh264Data() {
        let data = ESSpecificData(h264Data)
        #expect(data?.streamType == .h264)
        #expect(data?.elementaryPID == 256)
    }
}
