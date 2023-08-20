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
            guard let sampleBuffer = CMAudioSampleBufferTestUtil.makeSilence(44100, numSamples: 1024, channels: 2, presentaionTimeStamp: presentationTimeStamp) else {
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
            guard let sampleBuffer = CMAudioSampleBufferTestUtil.makeSilence(44100, numSamples: 1024, channels: 4, presentaionTimeStamp: presentationTimeStamp) else {
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
}
