import AVFoundation
import Foundation
import HaishinKit
import libsrt

/// An object that provides the interface to control a one-way channel over a SRTConnection.
public actor SRTStream {
    public private(set) var readyState: IOStreamReadyState = .idle
    private var name: String?
    private var action: (() async -> Void)?
    private lazy var stream = IOMediaConverter()
    private weak var connection: SRTConnection?
    private lazy var writer = TSWriter()
    private var observers: [any IOStreamObserver] = []
    private var bitrateStorategy: (any NetworkBitRateStrategy)?

    /// Creates a new stream object.
    public init(connection: SRTConnection) {
        self.connection = connection
        Task { await connection.addStream(self) }
    }

    /// Sends streaming audio, vidoe and data message from client.
    public func publish(_ name: String? = "") async {
        guard let name else {
            switch readyState {
            case .publishing:
                readyState = .idle
            default:
                break
            }
            return
        }
        if await connection?.connected == true {
            writer.expectedMedias.removeAll()
            if stream.videoInputFormat != nil {
                writer.videoFormat = stream.videoInputFormat
                writer.expectedMedias.insert(.video)
            }
            if stream.audioInputFormat != nil {
                writer.audioFormat = stream.audioInputFormat
                writer.expectedMedias.insert(.audio)
            }
            readyState = .publishing
            stream.startRunning()
            Task {
                for try await buffer in stream.video where stream.isRunning {
                    writer.append(buffer)
                }
            }
            Task {
                for await buffer in stream.audio where stream.isRunning {
                    writer.append(buffer.0, when: buffer.1)
                }
            }
            Task {
                for await data in writer.output where stream.isRunning {
                    await connection?.output(data)
                }
            }
        } else {
            action = { [weak self] in await self?.publish(name) }
        }
    }

    /// Playback streaming audio and video message from server.
    public func play(_ name: String? = "") async {
        guard let name else {
            switch readyState {
            case .playing:
                readyState = .idle
            default:
                break
            }
            return
        }
        if await connection?.connected == true {
            stream.startRunning()
            await connection?.listen()
            readyState = .playing
        } else {
            action = { [weak self] in await self?.play(name) }
        }
    }

    /// Stops playing or publishing and makes available other uses.
    public func close() async {
        if readyState == .idle {
            return
        }
        stream.stopRunning()
        readyState = .idle
    }

    func doInput(_ data: Data) {
        // muxer.read(data)
    }
}

extension SRTStream: IOStream {
    // MARK: IOStreamConvertible
    public var audioSettings: AudioCodecSettings {
        stream.audioSettings
    }

    public var videoSettings: VideoCodecSettings {
        stream.videoSettings
    }

    public func setAudioSettings(_ audioSettings: AudioCodecSettings) {
        stream.audioSettings = audioSettings
    }

    public func setVideoSettings(_ videoSettings: VideoCodecSettings) {
        stream.videoSettings = videoSettings
    }

    public func setBitrateStorategy(_ bitrateStorategy: (some NetworkBitRateStrategy)?) {
        self.bitrateStorategy = bitrateStorategy
    }

    public func append(_ sampleBuffer: CMSampleBuffer) {
        stream.append(sampleBuffer)
        observers.forEach { $0.stream(self, didOutput: sampleBuffer) }
    }

    public func attachAudioEngine(_ audioEngine: AVAudioEngine?) {
    }

    public func append(_ buffer: AVAudioBuffer, when: AVAudioTime) {
        stream.append(buffer, when: when)
        observers.forEach { $0.stream(self, didOutput: buffer, when: when) }
    }

    public func addObserver(_ observer: some IOStreamObserver) {
        guard !observers.contains(where: { $0 === observer }) else {
            return
        }
        observers.append(observer)
    }

    public func removeObserver(_ observer: some IOStreamObserver) {
        if let index = observers.firstIndex(where: { $0 === observer }) {
            observers.remove(at: index)
        }
    }

    public func dispatch(_ event: NetworkMonitorEvent) {
        bitrateStorategy?.adjustBitrate(event, stream: self)
    }
}
