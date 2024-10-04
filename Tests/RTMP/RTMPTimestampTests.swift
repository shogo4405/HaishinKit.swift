import Foundation
import Testing
import AVFoundation
@testable import HaishinKit

@Suite struct RTMPTimestampTests {
    @Test func cMTime() {
        let times: [CMTime] = [
            CMTime(value: 286340171565869, timescale: 1000000000),
            CMTime(value: 286340204889958, timescale: 1000000000),
            CMTime(value: 286340238223357, timescale: 1000000000),
            CMTime(value: 286340271560111, timescale: 1000000000),
            CMTime(value: 286340304906325, timescale: 1000000000),
            CMTime(value: 286340338232723, timescale: 1000000000),
            CMTime(value: 286340338232723, timescale: 1000000000),
        ]
        var timestamp = RTMPTimestamp<CMTime>()
        #expect(0 == timestamp.update(times[0]))
        #expect(33 == timestamp.update(times[1]))
        #expect(33 == timestamp.update(times[2]))
        #expect(33 == timestamp.update(times[3]))
        #expect(34 == timestamp.update(times[4]))
        #expect(33 == timestamp.update(times[5]))
    }

    @Test func aVAudioTime() {
        let times: [AVAudioTime] = [
            .init(hostTime: 6901294874500, sampleTime: 13802589749, atRate: 48000),
            .init(hostTime: 6901295386500, sampleTime: 13802590773, atRate: 48000),
            .init(hostTime: 6901295898500, sampleTime: 13802591797, atRate: 48000),
            .init(hostTime: 6901296410500, sampleTime: 13802592821, atRate: 48000),
            .init(hostTime: 6901296922500, sampleTime: 13802593845, atRate: 48000),
            .init(hostTime: 6901297434500, sampleTime: 13802594869, atRate: 48000),
        ]
        var timestamp = RTMPTimestamp<AVAudioTime>()
        #expect(0 == timestamp.update(times[0]))
        #expect(21 == timestamp.update(times[1]))
        #expect(21 == timestamp.update(times[2]))
        #expect(22 == timestamp.update(times[3]))
        #expect(21 == timestamp.update(times[4]))
        #expect(21 == timestamp.update(times[5]))
    }
}
