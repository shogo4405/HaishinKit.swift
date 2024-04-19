import Foundation
import AVFoundation
import XCTest

@testable import HaishinKit

final class IOAudioMixerBySingleTrackTests: XCTestCase {
    func testpKeep44100() {
        let mixer = IOAudioMixerBySingleTrack()
        mixer.settings = .init(
            mainTrack: 0,
            channels: 1,
            sampleRate: 44100,
            tracks: .init()
        )
        mixer.append(0, buffer: CMAudioSampleBufferFactory.makeSinWave(48000, numSamples: 1024, channels: 1)!)
        XCTAssertEqual(mixer.outputFormat?.sampleRate, 44100)
        mixer.append(0, buffer: CMAudioSampleBufferFactory.makeSinWave(44100, numSamples: 1024, channels: 1)!)
        XCTAssertEqual(mixer.outputFormat?.sampleRate, 44100)
    }

    func testpPassthrough16000_48000() {
        let mixer = IOAudioMixerBySingleTrack()
        mixer.settings = .init(
            mainTrack: 0,
            channels: 1,
            sampleRate: 0,
            tracks: .init()
        )
        mixer.append(0, buffer: CMAudioSampleBufferFactory.makeSinWave(16000, numSamples: 1024, channels: 1)!)
        XCTAssertEqual(mixer.outputFormat?.sampleRate, 16000)
        mixer.append(0, buffer: CMAudioSampleBufferFactory.makeSinWave(44100, numSamples: 1024, channels: 1)!)
        XCTAssertEqual(mixer.outputFormat?.sampleRate, 44100)
    }
}
