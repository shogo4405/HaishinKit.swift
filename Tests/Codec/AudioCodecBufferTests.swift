import Foundation
import XCTest
import AVFoundation

@testable import HaishinKit

final class AudioCodecBufferTests: XCTestCase {
    func testMonoSamples256_16bit() {
        guard
            let sampleBuffer = SinWaveUtil.makeCMSampleBuffer(44100, numSamples: 256),
            var asbd = sampleBuffer.formatDescription?.audioStreamBasicDescription else {
            XCTFail()
            return
        }
        let buffer = AudioCodecRingBuffer(&asbd, numSamples: 1024)
        for _ in 0..<1024/256 {
            _ = buffer?.appendSampleBuffer(sampleBuffer, offset: 0)
        }
        XCTAssertTrue(buffer?.isReady == true)
        let sampleBufferData = (try? sampleBuffer.dataBuffer?.dataBytes()) ?? Data()
        var expectedData = Data()
        expectedData.append(sampleBufferData)
        expectedData.append(sampleBufferData)
        expectedData.append(sampleBufferData)
        expectedData.append(sampleBufferData)
        if let pointer = buffer?.current.int16ChannelData?[0] {
            let data = Data(bytes: pointer, count: 1024 * 2)
            XCTAssertEqual(expectedData, data)
        }
    }

    func testStereoSamples256_16bit() {
        guard
            let sampleBuffer = SinWaveUtil.makeCMSampleBuffer(44100, numSamples: 256, channels: 2),
            var asbd = sampleBuffer.formatDescription?.audioStreamBasicDescription else {
            XCTFail()
            return
        }
        let buffer = AudioCodecRingBuffer(&asbd, numSamples: 1024)
        for _ in 0..<1024/256 {
            _ = buffer?.appendSampleBuffer(sampleBuffer, offset: 0)
        }
        XCTAssertTrue(buffer?.isReady == true)
        let sampleBufferData = (try? sampleBuffer.dataBuffer?.dataBytes()) ?? Data()
        var expectedData = Data()
        expectedData.append(sampleBufferData)
        expectedData.append(sampleBufferData)
        expectedData.append(sampleBufferData)
        expectedData.append(sampleBufferData)
        if let pointer = buffer?.current.int16ChannelData?[0] {
            let data = Data(bytes: pointer, count: 1024 * 2 * 2)
            XCTAssertEqual(expectedData, data)
        }
    }

    func testMonoSamples920_921_16bit() {
        guard
            let sampleBuffer_1 = SinWaveUtil.makeCMSampleBuffer(44100, numSamples: 920),
            let sampleBuffer_2 = SinWaveUtil.makeCMSampleBuffer(44100, numSamples: 921),
            var asbd = sampleBuffer_1.formatDescription?.audioStreamBasicDescription,
            let buffer = AudioCodecRingBuffer(&asbd, numSamples: 1024) else {
            XCTFail()
            return
        }

        let sampleBuffer_1Data = (try? sampleBuffer_1.dataBuffer?.dataBytes()) ?? Data()
        let sampleBuffer_2Data = (try? sampleBuffer_2.dataBuffer?.dataBytes()) ?? Data()

        var numBuffer = buffer.appendSampleBuffer(sampleBuffer_1, offset: 0)
        numBuffer = buffer.appendSampleBuffer(sampleBuffer_2, offset: 0)
        XCTAssertTrue(buffer.isReady)
        if let pointer = buffer.current.int16ChannelData?[0] {
            let data = Data(bytes: pointer, count: 1024 * 2)
            var expectedData = Data()
            expectedData.append(sampleBuffer_1Data)
            expectedData.append(sampleBuffer_2Data.subdata(in: 0..<numBuffer * 2))
            XCTAssertEqual(expectedData.bytes, data.bytes)
        } else {
            XCTFail()
        }
        buffer.next()
        XCTAssertFalse(buffer.isReady)
        XCTAssertEqual(numBuffer, 104)

        var expectedData = Data()
        expectedData.append(sampleBuffer_2Data.subdata(in: numBuffer * 2..<sampleBuffer_2Data.count))
        numBuffer = buffer.appendSampleBuffer(sampleBuffer_2, offset: numBuffer)

        if let pointer = buffer.current.int16ChannelData?[0] {
            let data = Data(bytes: pointer, count: expectedData.count)
            XCTAssertEqual(expectedData.bytes, data.bytes)
        } else {
            XCTFail()
        }
    }

    func testStereoSamples920_921_16bit() {
        guard
            let sampleBuffer_1 = SinWaveUtil.makeCMSampleBuffer(44100, numSamples: 920, channels: 2),
            let sampleBuffer_2 = SinWaveUtil.makeCMSampleBuffer(44100, numSamples: 921, channels: 2),
            var asbd = sampleBuffer_1.formatDescription?.audioStreamBasicDescription,
            let buffer = AudioCodecRingBuffer(&asbd, numSamples: 1024) else {
            XCTFail()
            return
        }

        let sampleBuffer_1Data = (try? sampleBuffer_1.dataBuffer?.dataBytes()) ?? Data()
        let sampleBuffer_2Data = (try? sampleBuffer_2.dataBuffer?.dataBytes()) ?? Data()
        var numBuffer = buffer.appendSampleBuffer(sampleBuffer_1, offset: 0)
        numBuffer = buffer.appendSampleBuffer(sampleBuffer_2, offset: 0)

        XCTAssertTrue(buffer.isReady)
        if let pointer = buffer.current.int16ChannelData?[0] {
            let data = Data(bytes: pointer, count: 1024 * 2 * 2)
            var expectedData = Data()
            expectedData.append(sampleBuffer_1Data)
            expectedData.append(sampleBuffer_2Data.subdata(in: 0..<numBuffer * 2 * 2))
            XCTAssertEqual(expectedData.bytes, data.bytes)
        } else {
            XCTFail()
        }
        buffer.next()
        XCTAssertFalse(buffer.isReady)
        XCTAssertEqual(numBuffer, 104)

        var expectedData = Data()
        expectedData.append(sampleBuffer_2Data.subdata(in: numBuffer * 2 * 2..<sampleBuffer_2Data.count))
        numBuffer = buffer.appendSampleBuffer(sampleBuffer_2, offset: numBuffer)

        if let pointer = buffer.current.int16ChannelData?[0] {
            let data = Data(bytes: pointer, count: expectedData.count)
            XCTAssertEqual(expectedData.bytes, data.bytes)
        } else {
            XCTFail()
        }
    }

    func testMonoSamples920_921_16bit_2() {
        guard
            let sampleBuffer_1 = SinWaveUtil.makeCMSampleBuffer(44100, numSamples: 920),
            let sampleBuffer_2 = SinWaveUtil.makeCMSampleBuffer(44100, numSamples: 921),
            var asbd = sampleBuffer_1.formatDescription?.audioStreamBasicDescription,
            let buffer = AudioCodecRingBuffer(&asbd, numSamples: 1024) else {
            XCTFail()
            return
        }
        let sampleBuffer_2Data = (try? sampleBuffer_2.dataBuffer?.dataBytes()) ?? Data()

        appendSampleBuffer(buffer, sampleBuffer: sampleBuffer_1, offset: 0)
        appendSampleBuffer(buffer, sampleBuffer: sampleBuffer_2, offset: 0)

        var expectedData = Data()
        expectedData.append(sampleBuffer_2Data.subdata(in: 104 * 2..<sampleBuffer_2Data.count))

        if let pointer = buffer.current.int16ChannelData?[0] {
            let data = Data(bytes: pointer, count: expectedData.count)
            XCTAssertEqual(expectedData.bytes, data.bytes)
        } else {
            XCTFail()
        }
    }

    func testStereoSamples920_921_16bit_2() {
        guard
            let sampleBuffer_1 = SinWaveUtil.makeCMSampleBuffer(44100, numSamples: 920, channels: 2),
            let sampleBuffer_2 = SinWaveUtil.makeCMSampleBuffer(44100, numSamples: 921, channels: 2),
            var asbd = sampleBuffer_1.formatDescription?.audioStreamBasicDescription,
            let buffer = AudioCodecRingBuffer(&asbd, numSamples: 1024) else {
            XCTFail()
            return
        }
        let sampleBuffer_2Data = (try? sampleBuffer_2.dataBuffer?.dataBytes()) ?? Data()

        appendSampleBuffer(buffer, sampleBuffer: sampleBuffer_1, offset: 0)
        appendSampleBuffer(buffer, sampleBuffer: sampleBuffer_2, offset: 0)

        var expectedData = Data()
        expectedData.append(sampleBuffer_2Data.subdata(in: 104 * 2 * 2..<sampleBuffer_2Data.count))

        if let pointer = buffer.current.int16ChannelData?[0] {
            let data = Data(bytes: pointer, count: expectedData.count)
            XCTAssertEqual(expectedData.bytes, data.bytes)
        } else {
            XCTFail()
        }
    }

    private func appendSampleBuffer(_ buffer: AudioCodecRingBuffer, sampleBuffer: CMSampleBuffer, offset: Int = 0) {
        let numSamples = buffer.appendSampleBuffer(sampleBuffer, offset: offset)
        if buffer.isReady {
            buffer.next()
        }
        if offset + numSamples < sampleBuffer.numSamples {
            appendSampleBuffer(buffer, sampleBuffer: sampleBuffer, offset: offset + numSamples)
        }
    }
}

