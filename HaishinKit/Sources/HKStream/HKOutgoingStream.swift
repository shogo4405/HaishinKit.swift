import AVFoundation
import Foundation

/// An object that provides a stream ingest feature.
public final class HKOutgoingStream {
    public private(set) var isRunning = false

    /// The asynchronous sequence for audio output.
    public var audioOutputStream: AsyncStream<(AVAudioBuffer, AVAudioTime)> {
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
    public var videoOutputStream: AsyncStream<CMSampleBuffer> {
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

    /// Specifies the video buffering count.
    public var videoInputBufferCounts = -1

    /// The asynchronous sequence for video input buffer.
    public var videoInputStream: AsyncStream<CMSampleBuffer> {
        if 0 < videoInputBufferCounts {
            return AsyncStream(CMSampleBuffer.self, bufferingPolicy: .bufferingNewest(videoInputBufferCounts)) { continuation in
                self.videoInputContinuation = continuation
            }
        } else {
            return AsyncStream { continuation in
                self.videoInputContinuation = continuation
            }
        }
    }

    /// The video input format.
    public private(set) var videoInputFormat: CMFormatDescription?

    private var audioCodec = AudioCodec()
    private var videoCodec = VideoCodec()
    private var videoInputContinuation: AsyncStream<CMSampleBuffer>.Continuation? {
        didSet {
            oldValue?.finish()
        }
    }

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
            videoInputContinuation?.yield(sampleBuffer)
        default:
            break
        }
    }

    /// Appends a sample buffer for publish.
    public func append(_ audioBuffer: AVAudioBuffer, when: AVAudioTime) {
        audioInputFormat = audioBuffer.format.formatDescription
        audioCodec.append(audioBuffer, when: when)
    }

    /// Appends a video buffer.
    public func append(video sampleBuffer: CMSampleBuffer) {
        videoCodec.append(sampleBuffer)
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
        isRunning = false
        videoCodec.stopRunning()
        audioCodec.stopRunning()
        videoInputContinuation = nil
    }
}
