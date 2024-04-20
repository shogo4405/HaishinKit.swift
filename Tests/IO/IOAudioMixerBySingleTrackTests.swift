import Foundation
import AVFoundation
import XCTest

@testable import HaishinKit

final class IOAudioMixerBySingleTrackTests: XCTestCase {
    func testKeep44100() {
        let mixer = IOAudioMixerBySingleTrack()
        mixer.settings = .init(
            channels: 1,
            sampleRate: 44100
        )
        mixer.append(0, buffer: CMAudioSampleBufferFactory.makeSinWave(48000, numSamples: 1024, channels: 1)!)
        XCTAssertEqual(mixer.outputFormat?.sampleRate, 44100)
        mixer.append(0, buffer: CMAudioSampleBufferFactory.makeSinWave(44100, numSamples: 1024, channels: 1)!)
        XCTAssertEqual(mixer.outputFormat?.sampleRate, 44100)
    }

    func test44100to48000() {
        let mixer = IOAudioMixerBySingleTrack()
        mixer.settings = .init(
            channels: 1,
            sampleRate: 44100
        )
        mixer.append(0, buffer: CMAudioSampleBufferFactory.makeSinWave(48000, numSamples: 1024, channels: 1)!)
        XCTAssertEqual(mixer.outputFormat?.sampleRate, 44100)
        mixer.settings = .init(
            channels: 1,
            sampleRate: 48000
        )
        mixer.append(0, buffer: CMAudioSampleBufferFactory.makeSinWave(44100, numSamples: 1024, channels: 1)!)
        XCTAssertEqual(mixer.outputFormat?.sampleRate, 48000)
    }

    func testpPassthrough16000_48000() {
        let mixer = IOAudioMixerBySingleTrack()
        mixer.settings = .init(
            channels: 1,
            sampleRate: 0
        )
        mixer.append(0, buffer: CMAudioSampleBufferFactory.makeSinWave(16000, numSamples: 1024, channels: 1)!)
        XCTAssertEqual(mixer.outputFormat?.sampleRate, 16000)
        mixer.append(0, buffer: CMAudioSampleBufferFactory.makeSinWave(44100, numSamples: 1024, channels: 1)!)
        XCTAssertEqual(mixer.outputFormat?.sampleRate, 44100)
    }

    func testInputFormats() {
        let mixer = IOAudioMixerBySingleTrack()
        mixer.settings = .init(
            channels: 1,
            sampleRate: 44100
        )
        mixer.append(0, buffer: CMAudioSampleBufferFactory.makeSinWave(48000, numSamples: 1024, channels: 1)!)
        let inputFormats = mixer.inputFormats
        XCTAssertEqual(inputFormats[0]?.sampleRate, 48000)
    }
}
