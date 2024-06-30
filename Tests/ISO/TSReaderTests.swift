import Foundation
import XCTest
import Logboard
import AVFAudio

@testable import HaishinKit

/*

final class TSReaderTests: XCTestCase {
    func testTSFileRead() {
        let bundle = Bundle(for: type(of: self))
        let url = URL(fileURLWithPath: bundle.path(forResource: "SampleVideo_360x240_5mb_2ch", ofType: "ts")!)
        do {
            let readerDelegate = TSReaderTestsResult()
            let fileHandle = try FileHandle(forReadingFrom: url)
            let reader = TSReader<TSReaderTestsResult>()
            reader.delegate = readerDelegate
            _ = reader.read(fileHandle.readDataToEndOfFile())
        } catch {
        }
    }

    func testTSFileRead_changeResolution() {
        let bundle = Bundle(for: type(of: self))
        let url = URL(fileURLWithPath: bundle.path(forResource: "change_video_resolution", ofType: "ts")!)
        do {
            let readerDelegate = TSReaderTestsResult()
            let fileHandle = try FileHandle(forReadingFrom: url)
            let reader = TSReader<TSReaderTestsResult>()
            reader.delegate = readerDelegate
            _ = reader.read(fileHandle.readDataToEndOfFile())
            XCTAssertEqual(readerDelegate.videoFormats[0].dimensions.width, 640)
            XCTAssertEqual(readerDelegate.videoFormats[0].dimensions.height, 360)
            XCTAssertEqual(readerDelegate.videoFormats[1].dimensions.width, 1280)
            XCTAssertEqual(readerDelegate.videoFormats[1].dimensions.height, 720)
            XCTAssertEqual(readerDelegate.videoFormats[2].dimensions.width, 1920)
            XCTAssertEqual(readerDelegate.videoFormats[2].dimensions.height, 1080)
        } catch {
        }
    }
}

private final class TSReaderTestsResult: TSReaderDelegate, AudioCodecDelegate {
    private var audioCodec: HaishinKit.AudioCodec<TSReaderTestsResult> = .init(lockQueue: DispatchQueue(label: "TSReaderAudioCodec"))
    
    var videoFormats: [CMFormatDescription] = []

    init() {
        audioCodec.delegate = self
        audioCodec.settings.format = .pcm
        audioCodec.startRunning()
    }

    func reader(_ reader: TSReader<TSReaderTestsResult>, id: UInt16, didRead formatDescription: CMFormatDescription) {
        switch formatDescription.mediaType {
        case .video:
            videoFormats.append(formatDescription)
        default:
            break
        }
    }

    func reader(_ reader: TSReader<TSReaderTestsResult>, id: UInt16, didRead sampleBuffer: CMSampleBuffer) {
        if sampleBuffer.formatDescription?.mediaType == .audio {
            audioCodec.append(sampleBuffer)
        }
    }

    func audioCodec(_ codec: HaishinKit.AudioCodec<TSReaderTestsResult>, didOutput outputFormat: AVAudioFormat?) {
    }

    func audioCodec(_ codec: HaishinKit.AudioCodec<TSReaderTestsResult>, errorOccurred error: HaishinKit.IOAudioUnitError) {
        // XCTFail()
    }

    func audioCodec(_ codec: HaishinKit.AudioCodec<TSReaderTestsResult>, didOutput audioBuffer: AVAudioBuffer, when: AVAudioTime) {
    }
}

*/
