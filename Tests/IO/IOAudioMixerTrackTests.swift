import Foundation
import AVFoundation
import XCTest

@testable import HaishinKit

final class IOAudioMixerTrackTests: XCTestCase {
    func testpKeep16000() {
        let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: true)!
        let track = IOAudioMixerTrack<IOAudioMixerTrackTests>(id: 0, outputFormat: format)
        track.delegate = self
        track.append(CMAudioSampleBufferFactory.makeSinWave(48000, numSamples: 1024, channels: 1)!)
        XCTAssertEqual(track.outputFormat.sampleRate, 16000)
        track.append(CMAudioSampleBufferFactory.makeSinWave(44100, numSamples: 1024, channels: 1)!)
        XCTAssertEqual(track.outputFormat.sampleRate, 16000)
    }

    func testpKeep44100() {
        let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 44100, channels: 1, interleaved: true)!
        let resampler = IOAudioMixerTrack<IOAudioMixerTrackTests>(id: 0, outputFormat: format)
        resampler.delegate = self
        resampler.append(CMAudioSampleBufferFactory.makeSinWave(48000, numSamples: 1024, channels: 1)!)
        XCTAssertEqual(resampler.outputFormat.sampleRate, 44100)
        resampler.append(CMAudioSampleBufferFactory.makeSinWave(44100, numSamples: 1024, channels: 1)!)
        XCTAssertEqual(resampler.outputFormat.sampleRate, 44100)
        resampler.append(CMAudioSampleBufferFactory.makeSinWave(44100, numSamples: 1024, channels: 1)!)
        XCTAssertEqual(resampler.outputFormat.sampleRate, 44100)
        resampler.append(CMAudioSampleBufferFactory.makeSinWave(16000, numSamples: 1024 * 20, channels: 1)!)
        XCTAssertEqual(resampler.outputFormat.sampleRate, 44100)
    }

    func testpKeep48000() {
        let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 48000, channels: 1, interleaved: true)!
        let track = IOAudioMixerTrack<IOAudioMixerTrackTests>(id: 0, outputFormat: format)
        track.delegate = self
        track.append(CMAudioSampleBufferFactory.makeSinWave(48000, numSamples: 1024, channels: 1)!)
        track.append(CMAudioSampleBufferFactory.makeSinWave(44100, numSamples: 1024 * 2, channels: 1)!)
    }

    func testpPassthrough48000_44100() {
        let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 44000, channels: 1, interleaved: true)!
        let resampler = IOAudioMixerTrack<IOAudioMixerTrackTests>(id: 0, outputFormat: format)
        resampler.delegate = self
        resampler.append(CMAudioSampleBufferFactory.makeSinWave(44000, numSamples: 1024, channels: 1)!)
        resampler.append(CMAudioSampleBufferFactory.makeSinWave(48000, numSamples: 1024, channels: 1)!)
    }

    func testpPassthrough16000_48000() {
        let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 48000, channels: 1, interleaved: true)!
        let track = IOAudioMixerTrack<IOAudioMixerTrackTests>(id: 0, outputFormat: format)
        track.delegate = self
        track.append(CMAudioSampleBufferFactory.makeSinWave(16000, numSamples: 1024, channels: 1)!)
        XCTAssertEqual(track.outputFormat.sampleRate, 48000)
        track.append(CMAudioSampleBufferFactory.makeSinWave(44100, numSamples: 1024, channels: 1)!)
    }
}

extension IOAudioMixerTrackTests: IOAudioMixerTrackDelegate {
    func track(_ track: IOAudioMixerTrack<IOAudioMixerTrackTests>, didOutput audioFormat: AVAudioFormat) {
    }

    func track(_ track: IOAudioMixerTrack<IOAudioMixerTrackTests>, didOutput audioPCMBuffer: AVAudioPCMBuffer, when: AVAudioTime) {
    }

    func track(_ track: IOAudioMixerTrack<IOAudioMixerTrackTests>, errorOccurred error: IOAudioUnitError) {
    }
}
