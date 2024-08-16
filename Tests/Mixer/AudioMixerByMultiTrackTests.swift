import Foundation
import AVFoundation
import XCTest

@testable import HaishinKit

final class AudioMixerByMultiTrackTests: XCTestCase {
    final class Result: AudioMixerDelegate {
        var outputs: [AVAudioPCMBuffer] = []
        var error: AudioMixerError?

        func audioMixer(_ audioMixer: some AudioMixer, track: UInt8, didInput buffer: AVAudioPCMBuffer, when: AVAudioTime) {
        }

        func audioMixer(_ audioMixer: some AudioMixer, didOutput audioFormat: AVAudioFormat) {
        }

        func audioMixer(_ audioMixer: some AudioMixer, didOutput audioBuffer: AVAudioPCMBuffer, when: AVAudioTime) {
            outputs.append(audioBuffer)
        }

        func audioMixer(_ audioMixer: some AudioMixer, errorOccurred error: AudioMixerError) {
            self.error = error
        }
    }

    func testKeep44100() {
        let result = Result()
        let mixer = AudioMixerByMultiTrack()
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
        let mixer = AudioMixerByMultiTrack()
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
        let mixer = AudioMixerByMultiTrack()
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
        let mixer = AudioMixerByMultiTrack()
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
