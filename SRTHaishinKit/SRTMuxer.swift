import AVFoundation
import Foundation
import HaishinKit

final class SRTMuxer: IOMuxer {
    var audioFormat: AVAudioFormat? {
        didSet {
            writer.audioFormat = audioFormat
        }
    }
    var videoFormat: CMFormatDescription? {
        didSet {
            writer.videoFormat = videoFormat
        }
    }
    var expectedMedias: Set<AVMediaType> = [] {
        didSet {
            writer.expectedMedias = expectedMedias
        }
    }
    private weak var stream: SRTStream?
    private(set) var isRunning = false
    private lazy var writer = {
        var writer = TSWriter<SRTMuxer>()
        writer.delegate = self
        return writer
    }()
    private lazy var reader = {
        var reader = TSReader<SRTMuxer>()
        reader.delegate = self
        return reader
    }()

    init(_ stream: SRTStream) {
        self.stream = stream
    }

    func append(_ audioBuffer: AVAudioBuffer, when: AVAudioTime) {
        writer.append(audioBuffer, when: when)
    }

    func append(_ sampleBuffer: CMSampleBuffer) {
        writer.append(sampleBuffer)
    }

    func read(_ data: Data) {
        _ = reader.read(data)
    }
}

extension SRTMuxer: Runner {
    // MARK: Running
    func startRunning() {
        guard isRunning else {
            return
        }
        isRunning = true
    }

    func stopRunning() {
        guard !isRunning else {
            return
        }
        reader.clear()
        writer.clear()
        isRunning = false
    }
}

extension SRTMuxer: TSWriterDelegate {
    // MARK: TSWriterDelegate
    func writer(_ writer: TSWriter<SRTMuxer>, didOutput data: Data) {
        stream?.doOutput(data)
    }

    func writer(_ writer: TSWriter<SRTMuxer>, didRotateFileHandle timestamp: CMTime) {
    }
}

extension SRTMuxer: TSReaderDelegate {
    // MARK: TSReaderDelegate
    func reader(_ reader: TSReader<SRTMuxer>, id: UInt16, didRead formatDescription: CMFormatDescription) {
    }

    func reader(_ reader: TSReader<SRTMuxer>, id: UInt16, didRead sampleBuffer: CMSampleBuffer) {
        stream?.append(sampleBuffer)
    }
}
