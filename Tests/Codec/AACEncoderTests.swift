import Foundation
import XCTest
import AVFoundation

@testable import HaishinKit

final class AACEncoderTests: XCTestCase {
    func testEncoderCMSampleBuffer44100_1024() {
        let encoder: AACEncoder = AACEncoder()
        encoder.delegate = self
        encoder.startRunning()
        for _ in 0..<10 {
            if let sampleBuffer: CMSampleBuffer = SinWaveUtil.createCMSampleBuffer(44100, numSamples: 1024) {
                encoder.encodeSampleBuffer(sampleBuffer)
            }
        }
    }

    func testEncoderCMSampleBuffer8000_256() {
    }
}

extension AACEncoderTests: AudioEncoderDelegate {
    // MARK: AudioEncoderDelegate
    func didSetFormatDescription(audio formatDescription: CMFormatDescription?) {
    }

    func sampleOutput(audio sampleBuffer: CMSampleBuffer) {
        print(sampleBuffer)
    }
}
