import AVFoundation
import Foundation

/// An object that provides a stream publish feature.
public final class HKStreamPublisher {
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

    private var audioCodec = AudioCodec()
    private var videoCodec = VideoCodec()

    /// Create a new instance.
    public init() {
    }

    /// Appends a sample buffer for publish.
    public func append(_ sampleBuffer: CMSampleBuffer) {
        switch sampleBuffer.formatDescription?.mediaType {
        case .audio?:
            audioCodec.append(sampleBuffer)
        case .video?:
            videoCodec.append(sampleBuffer)
        default:
            break
        }
    }

    /// Appends a sample buffer for publish.
    public func append(_ audioBuffer: AVAudioBuffer, when: AVAudioTime) {
        audioCodec.append(audioBuffer, when: when)
    }
}

extension HKStreamPublisher: Runner {
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
