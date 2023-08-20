import Foundation
import XCTest
import AVFoundation

@testable import HaishinKit

final class IOAudioMonitorTests: XCTestCase {
    func test3Channel_withoutCrash() {
        guard
            let sampleBuffer = CMAudioSampleBufferTestUtil.makeSilence(44100, numSamples: 256, channels: 3),
            var asbd = sampleBuffer.formatDescription?.audioStreamBasicDescription else {
            XCTFail()
            return
        }
        let monitor = IOAudioMonitor()
        monitor.inSourceFormat = asbd
        monitor.appendSampleBuffer(sampleBuffer)
    }
}
