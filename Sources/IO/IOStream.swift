import AVFoundation
import CoreImage
import CoreMedia
#if canImport(SwiftPMSupport)
import SwiftPMSupport
#endif
#if canImport(UIKit)
import UIKit
#endif

public protocol IOStreamConvertible: AnyObject {
    /// The current state of the stream.
    var readyState: IOStream.ReadyState { get async }

    var video: AsyncStream<CMSampleBuffer> { get async }

    /// Specifies the adaptibe bitrate strategy.
    // var bitrateStrategy: any IOStreamBitRateStrategyConvertible { get async }

    // var audioInputFormat: CMFormatDescription? { get async }

    /// Specifies the audio compression properties.
    var audioSettings: AudioCodecSettings { get async }

    // var videoInputFormat: CMFormatDescription? { get async }

    /// Specifies the video compression properties.
    var videoSettings: VideoCodecSettings { get async }

    /// Appends a CMSampleBuffer.
    /// - Parameters:
    ///   - sampleBuffer:The sample buffer to append.
    func append(_ sampleBuffer: CMSampleBuffer) async

    /// Appends an AVAudioBuffer.
    /// - Parameters:
    ///   - audioBuffer:The audio buffer to append.
    ///   - when: The audio time to append.
    ///   - track: Track number used for mixing.
    func append(_ audioBuffer: AVAudioBuffer, when: AVAudioTime) async

    func setAudioSettings(_ audioSettings: AudioCodecSettings) async

    func setVideoSettings(_ videoSettings: VideoCodecSettings) async

    // func setBitrateStorategy(_ bitrateStrategy: some IOStreamBitRateStrategyConvertible) async
}

/// The `IOStream` class is the foundation of a RTMPStream.
public final class IOStream {
    /// The enumeration defines the state an IOStream client is in.
    public enum ReadyState: Sendable, Equatable {
        public static func == (lhs: IOStream.ReadyState, rhs: IOStream.ReadyState) -> Bool {
            return lhs.rawValue == rhs.rawValue
        }

        /// IOStream has been created.
        case initialized
        /// IOStream waiting for new method.
        case open
        /// IOStream play() has been called.
        case play
        /// IOStream play and server was accepted as playing
        case playing
        /// IOStream publish() has been called
        case publish
        /// IOStream publish and server accpted as publising.
        case publishing
        /// IOStream close() has been called.
        case closed

        var rawValue: UInt8 {
            switch self {
            case .initialized:
                return 0
            case .open:
                return 1
            case .play:
                return 2
            case .playing:
                return 3
            case .publish:
                return 4
            case .publishing:
                return 5
            case .closed:
                return 6
            }
        }
    }

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

    public var video: AsyncStream<CMSampleBuffer> {
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

    private lazy var audioCodec = AudioCodec()
    private lazy var videoCodec = VideoCodec()

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

extension IOStream: Runner {
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
