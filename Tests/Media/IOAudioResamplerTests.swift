import Foundation
import AVFoundation
import XCTest

@testable import HaishinKit

final class NullIOAudioResamplerDelegate: IOAudioResamplerDelegate {
    func resampler(_ resampler: HaishinKit.IOAudioResampler<NullIOAudioResamplerDelegate>, didOutput audioFormat: AVAudioFormat) {
    }

    func resampler(_ resampler: HaishinKit.IOAudioResampler<NullIOAudioResamplerDelegate>, didOutput audioPCMBuffer: AVAudioPCMBuffer, when: AVAudioTime) {
    }

    func resampler(_ resampler: HaishinKit.IOAudioResampler<NullIOAudioResamplerDelegate>, errorOccurred error: HaishinKit.IOAudioUnitError) {
    }
}

final class IOAudioResamplerTests: XCTestCase {
    private lazy var nullIOAudioResamplerDelegate = NullIOAudioResamplerDelegate()

    func testpKeep16000() {
        let resampler = IOAudioResampler<NullIOAudioResamplerDelegate>()
        resampler.settings = .init(sampleRate: 16000, channels: 1)
        resampler.delegate = nullIOAudioResamplerDelegate
        resampler.append(CMAudioSampleBufferFactory.makeSinWave(48000, numSamples: 1024, channels: 1)!)
        XCTAssertEqual(resampler.outputFormat?.sampleRate, 16000)
        resampler.append(CMAudioSampleBufferFactory.makeSinWave(44100, numSamples: 1024, channels: 1)!)
        XCTAssertEqual(resampler.outputFormat?.sampleRate, 16000)
    }

    func testpKeep44100() {
        let resampler = IOAudioResampler<NullIOAudioResamplerDelegate>()
        resampler.settings = .init(sampleRate: 44100, channels: 1)
        resampler.delegate = nullIOAudioResamplerDelegate
        resampler.append(CMAudioSampleBufferFactory.makeSinWave(48000, numSamples: 1024, channels: 1)!)
        XCTAssertEqual(resampler.outputFormat?.sampleRate, 44100)
        resampler.append(CMAudioSampleBufferFactory.makeSinWave(44100, numSamples: 1024, channels: 1)!)
        XCTAssertEqual(resampler.outputFormat?.sampleRate, 44100)
        resampler.append(CMAudioSampleBufferFactory.makeSinWave(44100, numSamples: 1024, channels: 1)!)
        XCTAssertEqual(resampler.outputFormat?.sampleRate, 44100)
        resampler.append(CMAudioSampleBufferFactory.makeSinWave(16000, numSamples: 1024 * 20, channels: 1)!)
        XCTAssertEqual(resampler.outputFormat?.sampleRate, 44100)
    }

    func testpKeep48000() {
        let resampler = IOAudioResampler<NullIOAudioResamplerDelegate>()
        resampler.settings = .init(sampleRate: 48000, channels: 1)
        resampler.delegate = nullIOAudioResamplerDelegate
        resampler.append(CMAudioSampleBufferFactory.makeSinWave(48000, numSamples: 1024, channels: 1)!)
        XCTAssertEqual(resampler.outputFormat?.sampleRate, 48000)
        resampler.append(CMAudioSampleBufferFactory.makeSinWave(44100, numSamples: 1024 * 2, channels: 1)!)
        XCTAssertEqual(resampler.outputFormat?.sampleRate, 48000)
    }

    func testpPassthrough48000_44100() {
        let resampler = IOAudioResampler<NullIOAudioResamplerDelegate>()
        resampler.settings = .init(sampleRate: 0, channels: 1)
        resampler.delegate = nullIOAudioResamplerDelegate
        resampler.append(CMAudioSampleBufferFactory.makeSinWave(44000, numSamples: 1024, channels: 1)!)
        XCTAssertEqual(resampler.outputFormat?.sampleRate, 44000)
        resampler.append(CMAudioSampleBufferFactory.makeSinWave(48000, numSamples: 1024, channels: 1)!)
        XCTAssertEqual(resampler.outputFormat?.sampleRate, 48000)
    }

    func testpPassthrough44100_48000() {
        let resampler = IOAudioResampler<NullIOAudioResamplerDelegate>()
        resampler.settings = .init(sampleRate: 0, channels: 1)
        resampler.delegate = nullIOAudioResamplerDelegate
        resampler.append(CMAudioSampleBufferFactory.makeSinWave(48000, numSamples: 1024, channels: 1)!)
        XCTAssertEqual(resampler.outputFormat?.sampleRate, 48000)
        resampler.append(CMAudioSampleBufferFactory.makeSinWave(44100, numSamples: 1024, channels: 1)!)
        XCTAssertEqual(resampler.outputFormat?.sampleRate, 44100)
    }

    func testpPassthrough16000_48000() {
        let resampler = IOAudioResampler<NullIOAudioResamplerDelegate>()
        resampler.settings = .init(sampleRate: 0, channels: 1)
        resampler.delegate = nullIOAudioResamplerDelegate
        resampler.append(CMAudioSampleBufferFactory.makeSinWave(16000, numSamples: 1024, channels: 1)!)
        XCTAssertEqual(resampler.outputFormat?.sampleRate, 16000)
        resampler.append(CMAudioSampleBufferFactory.makeSinWave(44100, numSamples: 1024, channels: 1)!)
        XCTAssertEqual(resampler.outputFormat?.sampleRate, 44100)
    }
}
