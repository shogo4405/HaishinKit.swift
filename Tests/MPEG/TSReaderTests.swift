import Foundation
import XCTest
import Logboard
import CoreMedia
import AVFAudio

@testable import HaishinKit

final class TSReaderTests: XCTestCase {
    func testTSFileRead() {
        let bundle = Bundle(for: type(of: self))
        let url = URL(fileURLWithPath: bundle.path(forResource: "SampleVideo_360x240_5mb_2ch", ofType: "ts")!)
        do {
            let readerDelegate = TSReaderAudioCodec()
            let fileHandle = try FileHandle(forReadingFrom: url)
            let reader = TSReader()
            reader.delegate = readerDelegate
            _ = reader.read(fileHandle.readDataToEndOfFile())
        } catch {
        }
    }
}

private class TSReaderAudioCodec: TSReaderDelegate, AudioCodecDelegate {
    private var audioCodec: HaishinKit.AudioCodec = .init()

    init() {
        audioCodec.delegate = self
        audioCodec.destination = .pcm
        audioCodec.startRunning()
    }

    func reader(_ reader: HaishinKit.TSReader, id: UInt16, didRead formatDescription: CMFormatDescription) {
        if let audioStreamBasicDescription = formatDescription.audioStreamBasicDescription {
            audioCodec.inSourceFormat = audioStreamBasicDescription
        }
    }

    func reader(_ reader: HaishinKit.TSReader, id: UInt16, didRead sampleBuffer: CMSampleBuffer) {
        if sampleBuffer.formatDescription?.mediaType == .audio {
            audioCodec.appendSampleBuffer(sampleBuffer)
        }
    }

    func audioCodec(_ codec: HaishinKit.AudioCodec, didSet outputFormat: AVAudioFormat) {
    }

    func audioCodec(_ codec: HaishinKit.AudioCodec, errorOccurred error: HaishinKit.AudioCodec.Error) {
        // XCTFail()
    }

    func audioCodec(_ codec: HaishinKit.AudioCodec, didOutput audioBuffer: AVAudioBuffer, presentationTimeStamp: CMTime) {
    }
}

