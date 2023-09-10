import Foundation
import XCTest
import CoreMedia

@testable import HaishinKit

final class CMAudioSampleBufferFactoryTests: XCTestCase {
    func test48000_2chTest() {
        let streamBasicDescription = AudioStreamBasicDescription(
            mSampleRate: 48000.0,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: 0xc,
            mBytesPerPacket: 4,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4,
            mChannelsPerFrame: 2,
            mBitsPerChannel: 16,
            mReserved: 0
        )
        if let buffer = makeSampleBuffer(streamBasicDescription) {
            XCTAssertNotNil(CMAudioSampleBufferFactory.makeSampleBuffer(buffer, numSamples: 1024, presentationTimeStamp: .zero))
        } else {
            XCTFail()
        }
    }

    func test48000_4chTest() {
        let streamBasicDescription = AudioStreamBasicDescription(
            mSampleRate: 48000.0,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: 0xc,
            mBytesPerPacket: 8,
            mFramesPerPacket: 1,
            mBytesPerFrame: 8,
            mChannelsPerFrame: 4,
            mBitsPerChannel: 16,
            mReserved: 0
        )
        if let buffer = makeSampleBuffer(streamBasicDescription) {
            XCTAssertNotNil(CMAudioSampleBufferFactory.makeSampleBuffer(buffer, numSamples: 1024, presentationTimeStamp: .zero))
        } else {
            XCTFail()
        }
    }

    func test48000_3chTest() {
        let streamBasicDescription = AudioStreamBasicDescription(
            mSampleRate: 48000.0,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: 0xc,
            mBytesPerPacket: 6,
            mFramesPerPacket: 1,
            mBytesPerFrame: 6,
            mChannelsPerFrame: 3,
            mBitsPerChannel: 16,
            mReserved: 0
        )
        if let buffer = makeSampleBuffer(streamBasicDescription) {
            XCTAssertNotNil(CMAudioSampleBufferFactory.makeSampleBuffer(buffer, numSamples: 1024, presentationTimeStamp: .zero))
        } else {
            XCTFail()
        }
    }

    func test48000_2chTest_mac() {
        let streamBasicDescription = AudioStreamBasicDescription(
            mSampleRate: 48000.0,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: 0x29,
            mBytesPerPacket: 4,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4,
            mChannelsPerFrame: 1,
            mBitsPerChannel: 32,
            mReserved: 0
        )
        if let buffer = makeSampleBuffer(streamBasicDescription) {
            XCTAssertNotNil(CMAudioSampleBufferFactory.makeSampleBuffer(buffer, numSamples: 1024, presentationTimeStamp: .zero))
        } else {
            XCTFail()
        }
    }

    private func makeSampleBuffer(_ streamBasicDescription: AudioStreamBasicDescription) -> CMSampleBuffer? {
        guard let formatDescription = try? CMAudioFormatDescription(audioStreamBasicDescription: streamBasicDescription) else {
            return nil
        }
        var status: OSStatus = noErr
        var blockBuffer: CMBlockBuffer?
        let blockSize = 1024 * Int(streamBasicDescription.mBytesPerPacket)
        status = CMBlockBufferCreateWithMemoryBlock(
            allocator: nil,
            memoryBlock: nil,
            blockLength: blockSize,
            blockAllocator: nil,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: blockSize,
            flags: 0,
            blockBufferOut: &blockBuffer
        )
        guard let blockBuffer, status == noErr else {
            return nil
        }
        status = CMBlockBufferFillDataBytes(with: 0, blockBuffer: blockBuffer, offsetIntoDestination: 0, dataLength: blockSize)
        guard status == noErr else {
            return nil
        }
        var sampleBuffer: CMSampleBuffer?
        status = CMAudioSampleBufferCreateWithPacketDescriptions(
            allocator: nil,
            dataBuffer: blockBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: formatDescription,
            sampleCount: 1024,
            presentationTimeStamp: CMTimeMake(value: 1024, timescale: Int32(streamBasicDescription.mSampleRate)),
            packetDescriptions: nil,
            sampleBufferOut: &sampleBuffer
        )
        guard let sampleBuffer, status == noErr else {
            return nil
        }
        return sampleBuffer
    }
}
