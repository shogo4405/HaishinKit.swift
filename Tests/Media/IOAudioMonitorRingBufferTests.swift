import Foundation
import XCTest
import AVFoundation

@testable import HaishinKit

final class IOAudioMonitorRingBufferTests: XCTestCase {
    func testMonoAppendSampleBuffer_920() {
        appendSampleBuffer(920, channels: 1)
    }

    func testMonoAppendSampleBuffer_1024() {
        appendSampleBuffer(1024, channels: 1)
    }

    func testStereoAppendSampleBuffer_920() {
        appendSampleBuffer(920, channels: 2)
    }

    func testStereoAppendSampleBuffer_1024() {
        appendSampleBuffer(1024, channels: 2)
    }

    private func appendSampleBuffer(_ numSamples: Int, channels: UInt32) {
        var asbd = AudioStreamBasicDescription(
            mSampleRate: 44100,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: 0xc,
            mBytesPerPacket: 2 * channels,
            mFramesPerPacket: 1,
            mBytesPerFrame: 2 * channels,
            mChannelsPerFrame: channels,
            mBitsPerChannel: 16,
            mReserved: 0
        )
        let buffer = IOAudioMonitorRingBuffer(&asbd, bufferCounts: 3)
        guard
            let readBuffer = AVAudioPCMBuffer(pcmFormat: AVAudioFormat(streamDescription: &asbd)!, frameCapacity: AVAudioFrameCount(numSamples)),
            let sinWave = SinWaveUtil.makeCMSampleBuffer(44100, numSamples: numSamples, channels: channels) else {
            return
        }
        let bufferList = UnsafeMutableAudioBufferListPointer(readBuffer.mutableAudioBufferList)
        readBuffer.frameLength = AVAudioFrameCount(numSamples)
        for _ in 0..<30 {
            buffer?.appendSampleBuffer(sinWave)
            readBuffer.int16ChannelData?[0].assign(repeating: 0, count: numSamples)
            _ = buffer?.render(UInt32(numSamples), ioData: readBuffer.mutableAudioBufferList)
            XCTAssertEqual(sinWave.dataBuffer?.data?.bytes, Data(bytes: bufferList[0].mData!, count: numSamples * Int(channels) * 2).bytes)
        }
    }
}
