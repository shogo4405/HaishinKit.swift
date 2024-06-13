import AVFoundation
import CoreImage
import CoreMedia
#if canImport(SwiftPMSupport)
import SwiftPMSupport
#endif
#if canImport(UIKit)
import UIKit
#endif

/// The interface an IOStream uses to inform its delegate.
public protocol IOStreamDelegate: AnyObject {
    /// Tells the receiver that the ready state will change.
    func stream(_ stream: IOStream, willChangeReadyState state: IOStream.ReadyState)
    /// Tells the receiver that the ready state did change.
    func stream(_ stream: IOStream, didChangeReadyState state: IOStream.ReadyState)
}

public protocol IOStreamConvertible: AnyObject {
    /// The current state of the stream.
    var readyState: IOStream.ReadyState { get }

    /// Specifies the adaptibe bitrate strategy.
    var bitrateStrategy: any IOStreamBitRateStrategyConvertible { get }

    var audioInputFormat: CMFormatDescription? { get }

    /// Specifies the audio compression properties.
    var audioSettings: AudioCodecSettings { get  }

    var videoInputFormat: CMFormatDescription? { get }

    /// Specifies the video compression properties.
    var videoSettings: VideoCodecSettings { get }

    /// Appends a CMSampleBuffer.
    /// - Parameters:
    ///   - sampleBuffer:The sample buffer to append.
    func append(_ sampleBuffer: CMSampleBuffer)

    /// Appends an AVAudioBuffer.
    /// - Parameters:
    ///   - audioBuffer:The audio buffer to append.
    ///   - when: The audio time to append.
    ///   - track: Track number used for mixing.
    func append(_ audioBuffer: AVAudioBuffer, when: AVAudioTime)

    func attachMixer(_ mixer: IOMixer?)

    func setAudioSettings(_ audioSettings: AudioCodecSettings)

    func setVideoSettings(_ videoSettings: VideoCodecSettings)

    func setBitrateStorategy(_ bitrateStrategy: some IOStreamBitRateStrategyConvertible)

    func addObserver(_ observer: some IOStreamObserver)

    func removeObserver(_ observer: some IOStreamObserver)
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

    /// Specifies the adaptibe bitrate strategy.
    public var bitrateStrategy: any IOStreamBitRateStrategyConvertible = IOStreamBitRateStrategy() {
        didSet {
            bitrateStrategy.stream = self
            bitrateStrategy.setUp()
        }
    }

    public private(set) var audioInputFormat: CMFormatDescription?

    /// Specifies the audio compression properties.
    public var audioSettings: AudioCodecSettings {
        audioCodec.settings
    }

    public private(set) var videoInputFormat: CMFormatDescription?

    public private(set) var isRunning = false

    /// Specifies the video compression properties.
    public var videoSettings: VideoCodecSettings {
        videoCodec.settings
    }

    /// Specifies the delegate.
    public weak var delegate: (any IOStreamDelegate)?

    /// The current state of the stream.
    public var readyState: ReadyState = .initialized {
        willSet {
            guard readyState != newValue else {
                return
            }
            delegate?.stream(self, willChangeReadyState: readyState)
        }
        didSet {
            guard readyState != oldValue else {
                return
            }
            delegate?.stream(self, didChangeReadyState: readyState)
        }
    }

    private let muxer: any IOMuxer

    private weak var mixer: IOMixer? {
        didSet {
            oldValue?.removeStream(self)
            mixer?.addStream(self)
        }
    }

    private lazy var audioCodec = AudioCodec()
    private lazy var videoCodec = VideoCodec()
    private var observers: [any IOStreamObserver] = []

    public init(_ muxer: some IOMuxer) {
        self.muxer = muxer
    }

    deinit {
        observers.removeAll()
    }

    /// Adds an observer.
    public func addObserver(_ observer: some IOStreamObserver) {
        guard !observers.contains(where: { $0 === observer }) else {
            return
        }
        observers.append(observer)
    }

    /// Removes an observer.
    public func removeObserver(_ observer: some IOStreamObserver) {
        if let index = observers.firstIndex(where: { $0 === observer }) {
            observers.remove(at: index)
        }
    }
}

extension IOStream: IOStreamConvertible {
    // MARK: IOStreamConvertible
    public func attachMixer(_ mixer: IOMixer?) {
        self.mixer = mixer
    }

    public func setAudioSettings(_ audioSettings: AudioCodecSettings) {
        audioCodec.settings = audioSettings
    }

    public func setVideoSettings(_ videoSettings: VideoCodecSettings) {
        videoCodec.settings = videoSettings
    }

    public func setBitrateStorategy(_ bitrateStrategy: some IOStreamBitRateStrategyConvertible) {
        self.bitrateStrategy = bitrateStrategy
    }

    public func append(_ sampleBuffer: CMSampleBuffer) {
        switch sampleBuffer.formatDescription?.mediaType {
        case .audio:
            if audioInputFormat != sampleBuffer.formatDescription {
                audioInputFormat = sampleBuffer.formatDescription
            }
            if audioCodec.isRunning {
                audioCodec.append(sampleBuffer)
            }
        case .video:
            if videoInputFormat != sampleBuffer.formatDescription {
                videoInputFormat = sampleBuffer.formatDescription
            }
            videoCodec.append(sampleBuffer)
        default:
            break
        }
        observers.forEach { $0.stream(self, didOutput: sampleBuffer) }
    }

    public func append(_ audioBuffer: AVAudioBuffer, when: AVAudioTime) {
        if audioInputFormat != audioBuffer.format.formatDescription {
            audioInputFormat = audioBuffer.format.formatDescription
        }
        if audioCodec.isRunning {
            audioCodec.append(audioBuffer, when: when)
        }
        observers.forEach { $0.stream(self, didOutput: audioBuffer, when: when) }
    }
}

extension IOStream: Runner {
    public func startRunning() {
        guard !isRunning else {
            return
        }
        muxer.startRunning()
        videoCodec.startRunning()
        Task {
            let stream = videoCodec.outputStream
            for await buffer in stream where isRunning {
                muxer.append(buffer)
            }
        }
        audioCodec.startRunning()
        Task {
            let stream = audioCodec.outputStream
            for await buffer in stream where isRunning {
                muxer.append(buffer.0, when: buffer.1)
            }
        }
        isRunning = true
    }

    public func stopRunning() {
        guard isRunning else {
            return
        }
        muxer.stopRunning()
        videoCodec.stopRunning()
        audioCodec.stopRunning()
        isRunning = false
    }
}
