import AVFoundation
import Foundation

/// An object that provides a stream ingest feature.
public final class HKOutgoingStream {
    public private(set) var isRunning = false

    /// The asynchronous sequence for audio output.
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

    /// The audio input format.
    public private(set) var audioInputFormat: CMFormatDescription?

    /// The asynchronous sequence for video output.
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

    /// The video input format.
    public private(set) var videoInputFormat: CMFormatDescription?

    private var audioCodec = AudioCodec()
    private var videoCodec = VideoCodec()

    /// Create a new instance.
    public init() {
    }

    /// Appends a sample buffer for publish.
    public func append(_ sampleBuffer: CMSampleBuffer) {
        switch sampleBuffer.formatDescription?.mediaType {
        case .audio:
            audioInputFormat = sampleBuffer.formatDescription
            audioCodec.append(sampleBuffer)
        case .video:
            videoInputFormat = sampleBuffer.formatDescription
            videoCodec.append(sampleBuffer)
        default:
            break
        }
    }

    /// Appends a sample buffer for publish.
    public func append(_ audioBuffer: AVAudioBuffer, when: AVAudioTime) {
        audioInputFormat = audioBuffer.format.formatDescription
        audioCodec.append(audioBuffer, when: when)
    }
}

extension HKOutgoingStream: Runner {
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
