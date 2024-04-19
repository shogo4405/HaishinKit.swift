import Foundation
import AVFoundation
import XCTest

@testable import HaishinKit

final class IOAudioMixerByMultiTrackTests: XCTestCase {
    func testpKeep44100() {
        let mixer = IOAudioMixerByMultiTrack()
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
}
