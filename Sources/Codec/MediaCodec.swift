import AVFoundation
import Foundation

public final class MediaCodec {
    public private(set) var isRunning = false

    public var audio: AsyncStream<(AVAudioBuffer, AVAudioTime)> {
        return audioCodec.outputStream
    }

    /// Specifies the audio compression properties.
    public var audioSettings: AudioCodecSettings {
        get {
            audioCodec.settings
        }
        set {
            audioCodec.settings = newValue
        }
    }

    public private(set) var audioInputFormat: AVAudioFormat?

    public var video: AsyncThrowingStream<CMSampleBuffer, any Swift.Error> {
        return videoCodec.outputStream
    }

    /// Specifies the video compression properties.
    public var videoSettings: VideoCodecSettings {
        get {
            videoCodec.settings
        }
        set {
            videoCodec.settings = newValue
        }
    }

    public private(set) var videoInputFormat: CMFormatDescription?

    private var audioCodec = AudioCodec()
    private var videoCodec = VideoCodec()

    public init() {
    }

    public func append(_ sampleBuffer: CMSampleBuffer) {
        switch sampleBuffer.formatDescription?.mediaType {
        case .audio:
            break
        case .video:
            if videoInputFormat != sampleBuffer.formatDescription {
                videoInputFormat = sampleBuffer.formatDescription
            }
            videoCodec.append(sampleBuffer)
        default:
            break
        }
    }

    public func append(_ audioBuffer: AVAudioBuffer, when: AVAudioTime) {
        if audioInputFormat != audioBuffer.format {
            audioInputFormat = audioBuffer.format
        }
        if audioCodec.isRunning {
            audioCodec.append(audioBuffer, when: when)
        }
    }
}

extension MediaCodec: Runner {
    // MARK: Runner
    public func startRunning() {
        guard !isRunning else {
            return
        }
        videoCodec.startRunning()
        audioCodec.startRunning()
        isRunning = true
    }

    public func stopRunning() {
        guard isRunning else {
            return
        }
        videoCodec.stopRunning()
        audioCodec.stopRunning()
        isRunning = false
    }
}
