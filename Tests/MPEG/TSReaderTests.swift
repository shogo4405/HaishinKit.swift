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

private final class TSReaderAudioCodec: TSReaderDelegate, AudioCodecDelegate {
    private var audioCodec: HaishinKit.AudioCodec<TSReaderAudioCodec> = .init(lockQueue: DispatchQueue(label: "TSReaderAudioCodec"))

    init() {
        audioCodec.delegate = self
        audioCodec.settings.format = .pcm
        audioCodec.startRunning()
    }

    func reader(_ reader: HaishinKit.TSReader, id: UInt16, didRead formatDescription: CMFormatDescription) {
        audioCodec.inputFormat = AVAudioFormat(cmAudioFormatDescription: formatDescription)
    }

    func reader(_ reader: HaishinKit.TSReader, id: UInt16, didRead sampleBuffer: CMSampleBuffer) {
        if sampleBuffer.formatDescription?.mediaType == .audio {
            audioCodec.append(sampleBuffer)
        }
    }

    func audioCodec(_ codec: HaishinKit.AudioCodec<TSReaderAudioCodec>, didOutput outputFormat: AVAudioFormat) {
    }

    func audioCodec(_ codec: HaishinKit.AudioCodec<TSReaderAudioCodec>, errorOccurred error: HaishinKit.IOAudioUnitError) {
        // XCTFail()
    }

    func audioCodec(_ codec: HaishinKit.AudioCodec<TSReaderAudioCodec>, didOutput audioBuffer: AVAudioBuffer, when: AVAudioTime) {
    }
}

