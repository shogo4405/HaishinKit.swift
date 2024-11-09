import AVFoundation
import Foundation
import Testing

@testable import HaishinKit

@Suite struct AVCDecoderConfigurationRecordTests {
    @Test func main_1() {
        let data = Data([1, 66, 0, 40, 255, 225, 0, 16, 39, 66, 0, 40, 171, 64, 60, 3, 143, 83, 77, 192, 128, 128, 128, 128, 1, 0, 4, 40, 206, 60, 128])
        let avcc = AVCDecoderConfigurationRecord(data: data)
        let formatDescription = avcc.makeFormatDescription()
        #expect(formatDescription != nil)
    }

    @Test func main_2() {
        let data = Data([1, 66, 0, 40, 255, 225, 0, 11, 39, 66, 0, 40, 171, 64, 60, 3, 143, 83, 32, 1, 0, 4, 40, 206, 60, 128])
        let avcc = AVCDecoderConfigurationRecord(data: data)
        let formatDescription = avcc.makeFormatDescription()
        #expect(formatDescription != nil)
    }
}
