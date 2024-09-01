import Foundation
import AVFoundation
import XCTest

@testable import HaishinKit

final class AudioMixerBySingleTrackTests: XCTestCase {
    final class Result: AudioMixerDelegate {
        var outputs: [AVAudioPCMBuffer] = []

        func audioMixer(_ audioMixer: some AudioMixer, track: UInt8, didInput buffer: AVAudioPCMBuffer, when: AVAudioTime) {
        }

        func audioMixer(_ audioMixer: some AudioMixer, didOutput audioFormat: AVAudioFormat) {
        }

        func audioMixer(_ audioMixer: some AudioMixer, didOutput audioBuffer: AVAudioPCMBuffer, when: AVAudioTime) {
            outputs.append(audioBuffer)
        }

        func audioMixer(_ audioMixer: some AudioMixer, errorOccurred error: AudioMixerError) {
        }
    }

    func testKeep44100_1ch() {
        let mixer = AudioMixerBySingleTrack()
        mixer.settings = .init(
            sampleRate: 44100, channels: 1
        )
        mixer.append(0, buffer: CMAudioSampleBufferFactory.makeSinWave(48000, numSamples: 1024, channels: 1)!)
        XCTAssertEqual(mixer.outputFormat?.sampleRate, 44100)
        mixer.append(0, buffer: CMAudioSampleBufferFactory.makeSinWave(44100, numSamples: 1024, channels: 1)!)
        XCTAssertEqual(mixer.outputFormat?.sampleRate, 44100)
    }

    func test44100to48000_1ch() {
        let mixer = AudioMixerBySingleTrack()
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

    func test44100to48000_4ch_2ch() {
        let result = Result()
        let mixer = AudioMixerBySingleTrack()
        mixer.delegate = result
        mixer.settings = .init(
            sampleRate: 44100, channels: 0
        )
        mixer.append(0, buffer: CMAudioSampleBufferFactory.makeSinWave(48000, numSamples: 1024, channels: 4)!)
        XCTAssertEqual(mixer.outputFormat?.channelCount, 2)
        XCTAssertEqual(mixer.outputFormat?.sampleRate, 44100)
        mixer.settings = .init(
            sampleRate: 48000, channels: 0
        )
        mixer.append(0, buffer: CMAudioSampleBufferFactory.makeSinWave(44100, numSamples: 1024, channels: 4)!)
        mixer.append(0, buffer: CMAudioSampleBufferFactory.makeSinWave(44100, numSamples: 1024, channels: 4)!)
        XCTAssertEqual(mixer.outputFormat?.channelCount, 2)
        XCTAssertEqual(mixer.outputFormat?.sampleRate, 48000)
        XCTAssertEqual(result.outputs.count, 2)
    }

    func test44100to48000_4ch() {
        let result = Result()
        let mixer = AudioMixerBySingleTrack()
        mixer.delegate = result
        mixer.settings = .init(
            sampleRate: 44100, channels: 0
        )
        mixer.settings.maximumNumberOfChannels = 4
        mixer.append(0, buffer: CMAudioSampleBufferFactory.makeSinWave(48000, numSamples: 1024, channels: 4)!)
        XCTAssertEqual(mixer.outputFormat?.channelCount, 4)
        XCTAssertEqual(mixer.outputFormat?.sampleRate, 44100)
        mixer.settings = .init(
            sampleRate: 48000, channels: 0
        )
        mixer.settings.maximumNumberOfChannels = 4
        mixer.append(0, buffer: CMAudioSampleBufferFactory.makeSinWave(44100, numSamples: 1024, channels: 4)!)
        mixer.append(0, buffer: CMAudioSampleBufferFactory.makeSinWave(44100, numSamples: 1024, channels: 4)!)
        XCTAssertEqual(mixer.outputFormat?.channelCount, 4)
        XCTAssertEqual(mixer.outputFormat?.sampleRate, 48000)
        XCTAssertEqual(result.outputs.count, 2)
    }

    func testpPassthrough16000_48000() {
        let mixer = AudioMixerBySingleTrack()
        mixer.settings = .init(
            sampleRate: 0, channels: 1
        )
        mixer.append(0, buffer: CMAudioSampleBufferFactory.makeSinWave(16000, numSamples: 1024, channels: 1)!)
        XCTAssertEqual(mixer.outputFormat?.sampleRate, 16000)
        mixer.append(0, buffer: CMAudioSampleBufferFactory.makeSinWave(44100, numSamples: 1024, channels: 1)!)
        XCTAssertEqual(mixer.outputFormat?.sampleRate, 44100)
    }

    func testInputFormats() {
        let mixer = AudioMixerBySingleTrack()
        mixer.settings = .init(
            sampleRate: 44100, channels: 1
        )
        mixer.append(0, buffer: CMAudioSampleBufferFactory.makeSinWave(48000, numSamples: 1024, channels: 1)!)
        let inputFormats = mixer.inputFormats
        XCTAssertEqual(inputFormats[0]?.sampleRate, 48000)
    }
}
