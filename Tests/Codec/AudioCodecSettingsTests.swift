import Foundation
import XCTest
import AVFoundation

@testable import HaishinKit

final class AudioCodecSettingsTests: XCTestCase {
    func testChannelMaps() {
        XCTAssertEqual(AudioCodecSettings(bitRate: 0, sampleRate: 0, channels: 1, channelMap: [:]).makeChannelMap(1), [0])
        XCTAssertEqual(AudioCodecSettings(bitRate: 0, sampleRate: 0, channels: 1, channelMap: [0: 0]).makeChannelMap(1), [0])
        XCTAssertEqual(AudioCodecSettings(bitRate: 0, sampleRate: 0, channels: 1, channelMap: [0: 0, 1: 1]).makeChannelMap(1), [0])
        XCTAssertEqual(AudioCodecSettings(bitRate: 0, sampleRate: 0, channels: 1, channelMap: [0: -1]).makeChannelMap(1), [-1])
        XCTAssertEqual(AudioCodecSettings(bitRate: 0, sampleRate: 0, channels: 1, channelMap: [Int.max: Int.max]).makeChannelMap(1), [0])

        XCTAssertEqual(AudioCodecSettings(bitRate: 0, sampleRate: 0, channels: 2, channelMap: [:]).makeChannelMap(1), [0, -1])
        XCTAssertEqual(AudioCodecSettings(bitRate: 0, sampleRate: 0, channels: 2, channelMap: [0: 0]).makeChannelMap(1), [0, -1])
        XCTAssertEqual(AudioCodecSettings(bitRate: 0, sampleRate: 0, channels: 2, channelMap: [0: 1]).makeChannelMap(1), [0, -1])
        XCTAssertEqual(AudioCodecSettings(bitRate: 0, sampleRate: 0, channels: 2, channelMap: [0: -1, 1: -1]).makeChannelMap(1), [-1, -1])
        XCTAssertEqual(AudioCodecSettings(bitRate: 0, sampleRate: 0, channels: 2, channelMap: [0: 1, 1: Int.max]).makeChannelMap(1), [0, -1])

        XCTAssertEqual(AudioCodecSettings(bitRate: 0, sampleRate: 0, channels: 1, channelMap: [:]).makeChannelMap(2), [0])
        XCTAssertEqual(AudioCodecSettings(bitRate: 0, sampleRate: 0, channels: 1, channelMap: [0: 0]).makeChannelMap(2), [0])
        XCTAssertEqual(AudioCodecSettings(bitRate: 0, sampleRate: 0, channels: 1, channelMap: [0: 1]).makeChannelMap(2), [1])
        XCTAssertEqual(AudioCodecSettings(bitRate: 0, sampleRate: 0, channels: 1, channelMap: [0: -1]).makeChannelMap(1), [-1])
        XCTAssertEqual(AudioCodecSettings(bitRate: 0, sampleRate: 0, channels: 1, channelMap: [Int.max: 0]).makeChannelMap(2), [0])

        XCTAssertEqual(AudioCodecSettings(bitRate: 0, sampleRate: 0, channels: 2, channelMap: [:]).makeChannelMap(2), [0, 1])
        XCTAssertEqual(AudioCodecSettings(bitRate: 0, sampleRate: 0, channels: 2, channelMap: [0: 0]).makeChannelMap(2), [0, 1])
        XCTAssertEqual(AudioCodecSettings(bitRate: 0, sampleRate: 0, channels: 2, channelMap: [0: 0, 1: 1]).makeChannelMap(2), [0, 1])
        XCTAssertEqual(AudioCodecSettings(bitRate: 0, sampleRate: 0, channels: 2, channelMap: [0: -1, 1: -1]).makeChannelMap(2), [-1, -1])
        XCTAssertEqual(AudioCodecSettings(bitRate: 0, sampleRate: 0, channels: 2, channelMap: [0: -1, 1: 1]).makeChannelMap(2), [-1, 1])
        XCTAssertEqual(AudioCodecSettings(bitRate: 0, sampleRate: 0, channels: 2, channelMap: [0: 0, 1: 1, Int.max: Int.max]).makeChannelMap(2), [0, 1])
        XCTAssertEqual(AudioCodecSettings(bitRate: 0, sampleRate: 0, channels: 2, channelMap: [0: 0, 1: Int.max]).makeChannelMap(2), [0, 1])

        XCTAssertEqual(AudioCodecSettings(bitRate: 0, sampleRate: 0, channels: 2, channelMap: [:]).makeChannelMap(12), [0, 1])
        XCTAssertEqual(AudioCodecSettings(bitRate: 0, sampleRate: 0, channels: 2, channelMap: [0: -1, 1: 11]).makeChannelMap(12), [-1, 11])
    }
}

