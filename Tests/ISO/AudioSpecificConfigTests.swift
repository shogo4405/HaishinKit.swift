import Foundation
import Testing

@testable import HaishinKit

@Suite struct AudioSpecificConfigTests {
    @Test func bytes() {
        #expect(AudioSpecificConfig(type: .aacMain, frequency: .hz48000, channel: .frontCenter).bytes == [0b00001001, 0b10001000])
        #expect(AudioSpecificConfig(type: .aacMain, frequency: .hz44100, channel: .frontCenter).bytes == [0b00001010, 0b00001000])
        #expect(AudioSpecificConfig(type: .aacMain, frequency: .hz24000, channel: .frontCenter).bytes == [0b00001011, 0b00001000])
        #expect(AudioSpecificConfig(type: .aacMain, frequency: .hz16000, channel: .frontCenter).bytes == [0b00001100, 0b00001000])
        #expect(AudioSpecificConfig(type: .aacMain, frequency: .hz8000, channel: .frontCenter).bytes == [0b00001101, 0b10001000])
    }
}
