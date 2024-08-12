import Foundation
import AVFoundation
import XCTest

@testable import HaishinKit

final class IOAudioMixerByMultiTrackTests: XCTestCase {
    final class Result: IOAudioMixerDelegate {
        var outputs: [AVAudioPCMBuffer] = []
        var error: IOAudioUnitError?

        func audioMixer(_ audioMixer: some IOAudioMixerConvertible, track: UInt8, didInput buffer: AVAudioPCMBuffer, when: AVAudioTime) {
        }

        func audioMixer(_ audioMixer: some IOAudioMixerConvertible, didOutput audioFormat: AVAudioFormat) {
        }

        func audioMixer(_ audioMixer: some IOAudioMixerConvertible, didOutput audioBuffer: AVAudioPCMBuffer, when: AVAudioTime) {
            outputs.append(audioBuffer)
        }

        func audioMixer(_ audioMixer: some IOAudioMixerConvertible, errorOccurred error: IOAudioUnitError) {
            self.error = error
        }
    }

    func testKeep44100() {
        let result = Result()
        let mixer = IOAudioMixerByMultiTrack()
        mixer.delegate = result
        mixer.settings = .init(
            sampleRate: 44100, channels: 1
        )
        mixer.append(0, buffer: CMAudioSampleBufferFactory.makeSinWave(48000, numSamples: 1024, channels: 1)!)
        mixer.append(0, buffer: CMAudioSampleBufferFactory.makeSinWave(48000, numSamples: 1024, channels: 1)!)
        XCTAssertEqual(mixer.outputFormat?.sampleRate, 44100)
        mixer.append(0, buffer: CMAudioSampleBufferFactory.makeSinWave(44100, numSamples: 1024, channels: 1)!)
        XCTAssertEqual(mixer.outputFormat?.sampleRate, 44100)
        XCTAssertEqual(result.outputs.count, 2)
    }

    func test44100to48000() {
        let mixer = IOAudioMixerByMultiTrack()
        mixer.settings = .init(
            sampleRate: 44100, channels: 1
        )
        mixer.append(0, buffer: CMAudioSampleBufferFactory.makeSinWave(48000, numSamples: 1024, channels: 1)!)
        XCTAssertEqual(mixer.outputFormat?.sampleRate, 44100)
        mixer.settings = .init(
            sampleRate: 48000, channels: 1
        )
        mixer.append(0, buffer: CMAudioSampleBufferFactory.makeSinWave(44100, numSamples: 1024, channels: 1)!)
        XCTAssertEqual(mixer.outputFormat?.sampleRate, 48000)
    }

    func test48000_2ch() {
        let result = Result()
        let mixer = IOAudioMixerByMultiTrack()
        mixer.delegate = result
        mixer.settings = .init(
            sampleRate: 48000, channels: 2
        )
        mixer.append(1, buffer: CMAudioSampleBufferFactory.makeSinWave(48000, numSamples: 1024, channels: 2)!)
        mixer.append(0, buffer: CMAudioSampleBufferFactory.makeSinWave(48000, numSamples: 1024, channels: 2)!)
        XCTAssertEqual(mixer.outputFormat?.channelCount, 2)
        XCTAssertEqual(mixer.outputFormat?.sampleRate, 48000)
        mixer.append(1, buffer: CMAudioSampleBufferFactory.makeSinWave(48000, numSamples: 1024, channels: 2)!)
        mixer.append(0, buffer: CMAudioSampleBufferFactory.makeSinWave(48000, numSamples: 1024, channels: 2)!)
        XCTAssertEqual(result.outputs.count, 2)
        XCTAssertNil(result.error)
    }

    func testInputFormats() {
        let mixer = IOAudioMixerByMultiTrack()
        mixer.settings = .init(
            sampleRate: 44100, channels: 1
        )
        mixer.append(0, buffer: CMAudioSampleBufferFactory.makeSinWave(48000, numSamples: 1024, channels: 1)!)
        mixer.append(1, buffer: CMAudioSampleBufferFactory.makeSinWave(44100, numSamples: 1024, channels: 1)!)
        let inputFormats = mixer.inputFormats
        XCTAssertEqual(inputFormats[0]?.sampleRate, 48000)
        XCTAssertEqual(inputFormats[1]?.sampleRate, 44100)
    }
}
