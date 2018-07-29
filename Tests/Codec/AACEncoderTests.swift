import Foundation
import XCTest
import AVFoundation

@testable import HaishinKit

final class AACEncoderTests: XCTestCase {
    func testEncoderCMSampleBuffer44100_1024() {
        let encoder: AACEncoder = AACEncoder()
        encoder.startRunning()
        for _ in 0..<10 {
            if let sampleBuffer: CMSampleBuffer = SinWaveUtil.createCMSampleBuffer(44100, numSamples: 1024) {
                encoder.encodeSampleBuffer(sampleBuffer)
            }
        }
    }

    func testEncoderCMSampleBuffer48000_1024() {
        let encoder: AACEncoder = AACEncoder()
        encoder.startRunning()
        for _ in 0..<10 {
            if let sampleBuffer: CMSampleBuffer = SinWaveUtil.createCMSampleBuffer(48000.0, numSamples: 1024) {
                encoder.encodeSampleBuffer(sampleBuffer)
            }
        }
    }

    func testEncoderCMSampleBuffer24000_1024() {
        let encoder: AACEncoder = AACEncoder()
        encoder.startRunning()
        for _ in 0..<10 {
            if let sampleBuffer: CMSampleBuffer = SinWaveUtil.createCMSampleBuffer(24000.0, numSamples: 1024) {
                encoder.encodeSampleBuffer(sampleBuffer)
            }
        }
    }

    func testEncoderCMSampleBuffer16000_1024() {
        let encoder: AACEncoder = AACEncoder()
        encoder.startRunning()
        for _ in 0..<10 {
            if let sampleBuffer: CMSampleBuffer = SinWaveUtil.createCMSampleBuffer(16000.0, numSamples: 1024) {
                encoder.encodeSampleBuffer(sampleBuffer)
            }
        }
    }

    func testEncoderCMSampleBuffer8000_256() {
        let encoder: AACEncoder = AACEncoder()
        encoder.delegate = self
        encoder.startRunning()
        for _ in 0..<10 {
            if let sampleBuffer: CMSampleBuffer = SinWaveUtil.createCMSampleBuffer(8000.0, numSamples: 256) {
                encoder.encodeSampleBuffer(sampleBuffer)
            }
        }
    }
}

extension AACEncoderTests: AudioEncoderDelegate {
    // MARK: AudioEncoderDelegate
    func didSetFormatDescription(audio formatDescription: CMFormatDescription?) {
    }

    func sampleOutput(audio sampleBuffer: CMSampleBuffer) {
        // print(sampleBuffer.dataBuffer?.data)
    }
}
