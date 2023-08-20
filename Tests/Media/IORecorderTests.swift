import Foundation
import XCTest
import CoreMedia
import AVFoundation

@testable import HaishinKit

final class IORecorderTests: XCTestCase, IORecorderDelegate {
    func testRecorder2channel() {
        let recorder = IORecorder()
        recorder.delegate = self
        recorder.outputSettings = [.audio: [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 0,
            AVNumberOfChannelsKey: 0
        ]]
        recorder.startRunning()
        sleep(1)
        var presentationTimeStamp: CMTime = .zero
        for _ in 0...100 {
            guard let sampleBuffer = makeCMSampleBuffer(44100, numSamples: 1024, channels: 2, presentaionTimeStamp: presentationTimeStamp) else {
                return
            }
            presentationTimeStamp = CMTimeAdd(presentationTimeStamp, sampleBuffer.duration)
            recorder.appendSampleBuffer(sampleBuffer)
        }
        recorder.stopRunning()
        sleep(1)
    }

    func testRecorder4channel() {
        let recorder = IORecorder()
        recorder.delegate = self
        recorder.outputSettings = [.audio: [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 0,
            AVNumberOfChannelsKey: 0
        ]]
        recorder.startRunning()
        sleep(1)
        var presentationTimeStamp: CMTime = .zero
        for _ in 0...100 {
            guard let sampleBuffer = makeCMSampleBuffer(44100, numSamples: 1024, channels: 4, presentaionTimeStamp: presentationTimeStamp) else {
                return
            }
            presentationTimeStamp = CMTimeAdd(presentationTimeStamp, sampleBuffer.duration)
            recorder.appendSampleBuffer(sampleBuffer)
        }
        recorder.stopRunning()
        sleep(1)
    }

    func recorder(_ recorder: HaishinKit.IORecorder, errorOccured error: HaishinKit.IORecorder.Error) {
        // print("recorder:errorOccured", error)
    }

    func recorder(_ recorder: HaishinKit.IORecorder, finishWriting writer: AVAssetWriter) {
        // print("recorder:finishWriting")
    }

    private func makeCMSampleBuffer(_ sampleRate: Double = 44100, numSamples: Int = 1024, channels: UInt32 = 1, presentaionTimeStamp: CMTime = .zero) -> CMSampleBuffer? {
        var asbd = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: 0xc,
            mBytesPerPacket: 2 * channels,
            mFramesPerPacket: 1,
            mBytesPerFrame: 2 * channels,
            mChannelsPerFrame: channels,
            mBitsPerChannel: 16,
            mReserved: 0
        )
        var formatDescription: CMAudioFormatDescription? = nil
        var status: OSStatus = noErr
        var blockBuffer: CMBlockBuffer?
        let blockSize = numSamples * Int(asbd.mBytesPerPacket)
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
        status = CMAudioFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            asbd: &asbd,
            layoutSize: 0,
            layout: nil,
            magicCookieSize: 0,
            magicCookie: nil,
            extensions: nil,
            formatDescriptionOut: &formatDescription
        )

        guard let blockBuffer, status == noErr else {
            return nil
        }
        status = CMBlockBufferFillDataBytes(
            with: 0,
            blockBuffer: blockBuffer,
            offsetIntoDestination: 0,
            dataLength: blockSize
        )
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
            formatDescription: formatDescription!,
            sampleCount: numSamples,
            presentationTimeStamp: presentaionTimeStamp,
            packetDescriptions: nil,
            sampleBufferOut: &sampleBuffer
        )
        guard let sampleBuffer, status == noErr else {
            return nil
        }
        return sampleBuffer
    }
}
