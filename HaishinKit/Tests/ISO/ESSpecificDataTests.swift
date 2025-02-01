import CoreMedia
import Foundation
import Testing

@testable import HaishinKit

@Suite struct ESSpecificDataTests {
    private let AACData = Data([15, 225, 1, 240, 6, 10, 4, 117, 110, 100, 0])
    private let H264Data = Data([27, 225, 0, 240, 0, 15, 225, 1, 240, 6, 10, 4, 117, 110, 100, 0])

    @Test func readAACData() {
        let data = ESSpecificData(AACData)
        #expect(data?.streamType == .adtsAac)
        #expect(data?.elementaryPID == 257)
    }

    @Test func readH264Data() {
        let data = ESSpecificData(H264Data)
        #expect(data?.streamType == .h264)
        #expect(data?.elementaryPID == 256)
    }
}
