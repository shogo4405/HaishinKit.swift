import AVFoundation
import Foundation
import Testing

@testable import HaishinKit

@Suite struct AudioCodecSettingsFormatTests {
    @Test func opusSampleRate() {
        #expect(AudioCodecSettings.Format.opus.makeSampleRate(49000, output: 0) == 48000.0)
        #expect(AudioCodecSettings.Format.opus.makeSampleRate(44100, output: 0) == 48000.0)
        #expect(AudioCodecSettings.Format.opus.makeSampleRate(20000, output: 0) == 16000.0)
        #expect(AudioCodecSettings.Format.opus.makeSampleRate(1000, output: 0) == 8000.0)
    }

    @Test func aacSampleRate() {
        #expect(AudioCodecSettings.Format.aac.makeSampleRate(48000, output: 44100) == 44100.0)
        #expect(AudioCodecSettings.Format.aac.makeSampleRate(44100, output: 0) == 44100.0)
        #expect(AudioCodecSettings.Format.aac.makeSampleRate(20000, output: 0) == 20000.0)
    }
}
