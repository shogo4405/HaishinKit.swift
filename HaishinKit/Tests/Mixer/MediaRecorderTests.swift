import AVFoundation
import CoreMedia
import Foundation
import Testing

@testable import HaishinKit

/*
 final class IOStreamRecorderTests: XCTestCase, IOStreamRecorderDelegate {
 func testRecorder2channel() {
 let recorder = IOStreamRecorder()
 recorder.delegate = self
 recorder.settings = [.audio: [
 AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
 AVSampleRateKey: 0,
 AVNumberOfChannelsKey: 0
 ]]
 recorder.startRunning()
 sleep(1)
 var presentationTimeStamp: CMTime = .zero
 for _ in 0...100 {
 guard let sampleBuffer = CMAudioSampleBufferFactory.makeSilence(44100, numSamples: 1024, channels: 2, presentaionTimeStamp: presentationTimeStamp) else {
 return
 }
 presentationTimeStamp = CMTimeAdd(presentationTimeStamp, sampleBuffer.duration)
 recorder.append(sampleBuffer)
 }
 recorder.stopRunning()
 sleep(1)
 }

 func testRecorder4channel() {
 let recorder = IOStreamRecorder()
 recorder.delegate = self
 recorder.settings = [.audio: [
 AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
 AVSampleRateKey: 0,
 AVNumberOfChannelsKey: 0
 ]]
 recorder.startRunning()
 sleep(1)
 var presentationTimeStamp: CMTime = .zero
 for _ in 0...100 {
 guard let sampleBuffer = CMAudioSampleBufferFactory.makeSilence(44100, numSamples: 1024, channels: 4, presentaionTimeStamp: presentationTimeStamp) else {
 return
 }
 presentationTimeStamp = CMTimeAdd(presentationTimeStamp, sampleBuffer.duration)
 recorder.append(sampleBuffer)
 }
 recorder.stopRunning()
 sleep(1)
 }

 func recorder(_ recorder: HaishinKit.IOStreamRecorder, errorOccured error: IOStreamRecorder.Error) {
 // print("recorder:errorOccured", error)
 }

 func recorder(_ recorder: HaishinKit.IOStreamRecorder, finishWriting writer: AVAssetWriter) {
 // print("recorder:finishWriting")
 }
 }
 */
