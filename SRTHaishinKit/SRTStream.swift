import AVFoundation
import Foundation
import HaishinKit
import libsrt

/// An object that provides the interface to control a one-way channel over a SRTConnection.
public final class SRTStream {
    private var name: String?
    private var action: (() -> Void)?
    private weak var connection: SRTConnection?

    private lazy var muxer: SRTMuxer = {
        SRTMuxer(self)
    }()

    private lazy var stream: IOStream = {
        let stream = IOStream(muxer)
        stream.delegate = self
        return stream
    }()

    /// Creates a new stream object.
    public init(connection: SRTConnection) {
        self.connection = connection
        self.connection?.addStream(self)
    }

    deinit {
        connection = nil
    }

    /// Sends streaming audio, vidoe and data message from client.
    public func publish(_ name: String? = "") {
        guard let name else {
            switch readyState {
            case .publish, .publishing:
                readyState = .open
            default:
                break
            }
            return
        }
        if connection?.connected == true {
            readyState = .publish
        } else {
            action = { [weak self] in self?.publish(name) }
        }
    }

    /// Playback streaming audio and video message from server.
    public func play(_ name: String? = "") {
        guard let name else {
            switch readyState {
            case .play, .playing:
                readyState = .open
            default:
                break
            }
            return
        }
        if connection?.connected == true {
            readyState = .play
        } else {
            action = { [weak self] in self?.play(name) }
        }
    }

    /// Stops playing or publishing and makes available other uses.
    public func close() {
        if readyState == .closed || readyState == .initialized {
            return
        }
        readyState = .closed
    }

    func doInput(_ data: Data) {
        muxer.read(data)
    }

    func doOutput(_ data: Data) {
        connection?.output(data)
    }
}

extension SRTStream: IOStreamConvertible {
    public func setAudioSettings(_ audioSettings: AudioCodecSettings) {
        stream.setAudioSettings(audioSettings)
    }

    public func setVideoSettings(_ videoSettings: VideoCodecSettings) {
        stream.setVideoSettings(videoSettings)
    }

    public func setBitrateStorategy(_ bitrateStrategy: some IOStreamBitRateStrategyConvertible) {
        stream.setBitrateStorategy(bitrateStrategy)
    }

    // MARK: IOStreamConvertible
    public private(set) var readyState: IOStream.ReadyState {
        get {
            stream.readyState
        }
        set {
            stream.readyState = newValue
        }
    }

    public var bitrateStrategy: any IOStreamBitRateStrategyConvertible {
        stream.bitrateStrategy
    }

    public var audioInputFormat: CMFormatDescription? {
        stream.audioInputFormat
    }

    public var audioSettings: AudioCodecSettings {
        stream.audioSettings
    }

    public var videoInputFormat: CMFormatDescription? {
        stream.videoInputFormat
    }

    public var videoSettings: VideoCodecSettings {
        stream.videoSettings
    }

    public func attachMixer(_ mixer: IOMixer?) {
        stream.attachMixer(mixer)
    }

    public func append(_ sampleBuffer: CMSampleBuffer) {
        stream.append(sampleBuffer)
    }

    public func append(_ audioBuffer: AVAudioBuffer, when: AVAudioTime) {
        stream.append(audioBuffer, when: when)
    }

    public func addObserver(_ observer: some IOStreamObserver) {
        stream.addObserver(observer)
    }

    public func removeObserver(_ observer: some IOStreamObserver) {
        stream.removeObserver(observer)
    }
}

extension SRTStream: IOStreamDelegate {
    public func stream(_ stream: IOStream, willChangeReadyState state: IOStream.ReadyState) {
    }

    public func stream(_ stream: IOStream, didChangeReadyState state: IOStream.ReadyState) {
        switch readyState {
        case .play:
            stream.startRunning()
            connection?.listen()
            readyState = .playing
        case .publish:
            muxer.expectedMedias.removeAll()
            if videoInputFormat != nil {
                muxer.expectedMedias.insert(.video)
            }
            if audioInputFormat != nil {
                muxer.expectedMedias.insert(.audio)
            }
            readyState = .publishing
            stream.startRunning()
        default:
            break
        }
    }
}
