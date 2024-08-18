import AVFoundation
import Foundation
import HaishinKit
import libsrt

/// An actor that provides the interface to control a one-way channel over a SRTConnection.
public actor SRTStream {
    public private(set) var readyState: HKStreamReadyState = .idle
    private var name: String?
    private var action: (() async -> Void)?
    private weak var connection: SRTConnection?
    private lazy var writer = TSWriter()
    private lazy var reader = TSReader()
    private lazy var player = HKStreamPlayer(self)
    private lazy var publisher = HKStreamPublisher()
    private var outputs: [any HKStreamOutput] = []
    private var videoFormat: CMFormatDescription?
    private var audioFormat: CMFormatDescription?
    private var bitrateStorategy: (any HKStreamBitRateStrategy)?

    /// Creates a new stream object.
    public init(connection: SRTConnection) {
        self.connection = connection
        Task { await connection.addStream(self) }
    }

    deinit {
        outputs.removeAll()
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
            readyState = .publishing
            publisher.startRunning()
            writer.expectedMedias.removeAll()
            if let videoFormat {
                writer.expectedMedias.insert(.video)
            }
            if let audioFormat {
                writer.expectedMedias.insert(.audio)
            }
            Task {
                for try await buffer in publisher.video where publisher.isRunning {
                    append(buffer)
                }
            }
            Task {
                for await buffer in publisher.audio where publisher.isRunning {
                    append(buffer.0, when: buffer.1)
                }
            }
            Task {
                for await data in writer.output where publisher.isRunning {
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
            await player.startRunning()
            await connection?.listen()
            Task {
                for try await buffer in reader.output where await player.isRunning {
                    await player.append(buffer.1)
                }
            }
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
        publisher.stopRunning()
        Task { await player.stopRunning() }
        readyState = .idle
    }

    func doInput(_ data: Data) {
        _ = reader.read(data)
    }
}

extension SRTStream: HKStream {
    // MARK: HKStream
    public var audioSettings: AudioCodecSettings {
        publisher.audioSettings
    }

    public var videoSettings: VideoCodecSettings {
        publisher.videoSettings
    }

    public func setAudioSettings(_ audioSettings: AudioCodecSettings) {
        publisher.audioSettings = audioSettings
    }

    public func setVideoSettings(_ videoSettings: VideoCodecSettings) {
        publisher.videoSettings = videoSettings
    }

    public func setBitrateStorategy(_ bitrateStorategy: (some HKStreamBitRateStrategy)?) {
        self.bitrateStorategy = bitrateStorategy
    }

    public func append(_ sampleBuffer: CMSampleBuffer) {
        switch sampleBuffer.formatDescription?.mediaType {
        case .video:
            switch readyState {
            case .publishing:
                writer.videoFormat = sampleBuffer.formatDescription
                if sampleBuffer.formatDescription?.isCompressed == true {
                    writer.append(sampleBuffer)
                } else {
                    publisher.append(sampleBuffer)
                }
            default:
                break
            }
            if sampleBuffer.formatDescription?.isCompressed == false {
                videoFormat = sampleBuffer.formatDescription
                outputs.forEach { $0.stream(self, didOutput: sampleBuffer) }
            }
        default:
            break
        }
    }

    public func append(_ audioBuffer: AVAudioBuffer, when: AVAudioTime) {
        switch readyState {
        case .publishing:
            switch audioBuffer {
            case let audioBuffer as AVAudioPCMBuffer:
                publisher.append(audioBuffer, when: when)
            case let audioBuffer as AVAudioCompressedBuffer:
                writer.audioFormat = audioBuffer.format
                writer.append(audioBuffer, when: when)
            default:
                break
            }
        default:
            break
        }
        if audioBuffer is AVAudioPCMBuffer {
            audioFormat = audioBuffer.format.formatDescription
            outputs.forEach { $0.stream(self, didOutput: audioBuffer, when: when) }
        }
    }

    public func attachAudioPlayer(_ audioPlayer: AudioPlayer?) {
        Task {
            await player.attachAudioPlayer(audioPlayer)
        }
    }

    public func addOutput(_ observer: some HKStreamOutput) {
        guard !outputs.contains(where: { $0 === observer }) else {
            return
        }
        outputs.append(observer)
    }

    public func removeOutput(_ observer: some HKStreamOutput) {
        if let index = outputs.firstIndex(where: { $0 === observer }) {
            outputs.remove(at: index)
        }
    }

    public func dispatch(_ event: NetworkMonitorEvent) {
        bitrateStorategy?.adjustBitrate(event, stream: self)
    }
}

extension SRTStream: MediaMixerOutput {
    // MARK: MediaMixerOutput
    nonisolated public func mixer(_ mixer: MediaMixer, track: UInt8, didOutput sampleBuffer: CMSampleBuffer) {
        guard track == UInt8.max else {
            return
        }
        Task { await append(sampleBuffer) }
    }

    nonisolated public func mixer(_ mixer: MediaMixer, track: UInt8, didOutput buffer: AVAudioPCMBuffer, when: AVAudioTime) {
        guard track == UInt8.max else {
            return
        }
        Task { await append(buffer, when: when) }
    }
}
