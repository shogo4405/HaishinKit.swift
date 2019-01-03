import Foundation
import XCTest
import AVFoundation

@testable import HaishinKit

final class AudioConverterTests: XCTestCase {
    func testEncoderCMSampleBuffer44100_1024() {
        let encoder: AudioConverter = AudioConverter()
        encoder.startRunning()
        for _ in 0..<10 {
            if let sampleBuffer: CMSampleBuffer = SinWaveUtil.createCMSampleBuffer(44100, numSamples: 1024) {
                encoder.encodeSampleBuffer(sampleBuffer)
            }
        }
    }

    func testEncoderCMSampleBuffer48000_1024() {
        let encoder: AudioConverter = AudioConverter()
        encoder.startRunning()
        for _ in 0..<10 {
            if let sampleBuffer: CMSampleBuffer = SinWaveUtil.createCMSampleBuffer(48000.0, numSamples: 1024) {
                encoder.encodeSampleBuffer(sampleBuffer)
            }
        }
    }

    func testEncoderCMSampleBuffer24000_1024() {
        let encoder: AudioConverter = AudioConverter()
        encoder.startRunning()
        for _ in 0..<10 {
            if let sampleBuffer: CMSampleBuffer = SinWaveUtil.createCMSampleBuffer(24000.0, numSamples: 1024) {
                encoder.encodeSampleBuffer(sampleBuffer)
            }
        }
    }

    func testEncoderCMSampleBuffer16000_1024() {
        let encoder: AudioConverter = AudioConverter()
        encoder.startRunning()
        for _ in 0..<10 {
            if let sampleBuffer: CMSampleBuffer = SinWaveUtil.createCMSampleBuffer(16000.0, numSamples: 1024) {
                encoder.encodeSampleBuffer(sampleBuffer)
            }
        }
    }

    func testEncoderCMSampleBuffer8000_256() {
        let encoder: AudioConverter = AudioConverter()
        encoder.delegate = self
        encoder.startRunning()
        for _ in 0..<10 {
            if let sampleBuffer: CMSampleBuffer = SinWaveUtil.createCMSampleBuffer(8000.0, numSamples: 256) {
                encoder.encodeSampleBuffer(sampleBuffer)
            }
        }
    }
}

extension AudioConverterTests: AudioConverterDelegate {
    // MARK: AudioConverterDelegate
    func sampleOutput(audio data: UnsafeMutableAudioBufferListPointer, presentationTimeStamp: CMTime) {
    }

    func didSetFormatDescription(audio formatDescription: CMFormatDescription?) {
    }
}
