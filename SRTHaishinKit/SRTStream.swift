import AVFoundation
import Foundation
import HaishinKit
import libsrt

/// An object that provides the interface to control a one-way channel over a SRTConnection.
public actor SRTStream {
    public private(set) var readyState: HKStreamReadyState = .idle
    private var name: String?
    private var action: (() async -> Void)?
    private weak var connection: SRTConnection?
    private lazy var writer = TSWriter()
    private lazy var reader = TSReader()
    private lazy var mediaLink = MediaLink()
    private lazy var mediaCodec = MediaCodec()
    private var outputs: [any HKStreamOutput] = []
    private var bitrateStorategy: (any HKStreamBitRateStrategy)?
    private var audioPlayerNode: AudioPlayerNode?

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
            writer.expectedMedias.removeAll()
            if mediaCodec.videoInputFormat != nil {
                writer.videoFormat = mediaCodec.videoInputFormat
                writer.expectedMedias.insert(.video)
            }
            if mediaCodec.audioInputFormat != nil {
                writer.audioFormat = mediaCodec.audioInputFormat
                writer.expectedMedias.insert(.audio)
            }
            readyState = .publishing
            mediaCodec.startRunning()
            Task {
                for try await buffer in mediaCodec.video where mediaCodec.isRunning {
                    writer.append(buffer)
                }
            }
            Task {
                for await buffer in mediaCodec.audio where mediaCodec.isRunning {
                    writer.append(buffer.0, when: buffer.1)
                }
            }
            Task {
                for await data in writer.output where mediaCodec.isRunning {
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
            mediaCodec.startRunning()
            Task {
                await mediaLink.startRunning()
                while mediaCodec.isRunning {
                    do {
                        for try await video in mediaCodec.video where mediaCodec.isRunning {
                            await mediaLink.enqueue(video)
                        }
                    } catch {
                        logger.error(error)
                    }
                }
            }
            Task {
                guard let audioPlayerNode else {
                    return
                }
                await audioPlayerNode.startRunning()
                for await audio in mediaCodec.audio where mediaCodec.isRunning {
                    await audioPlayerNode.enqueue(audio.0, when: audio.1)
                }
            }
            Task {
                for try await buffer in reader.output where mediaCodec.isRunning {
                    mediaCodec.append(buffer.1)
                }
            }
            Task {
                for await video in await mediaLink.dequeue where mediaCodec.isRunning {
                    outputs.forEach { $0.stream(self, didOutput: video) }
                }
            }
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
        mediaCodec.stopRunning()
        readyState = .idle
    }

    func doInput(_ data: Data) {
        _ = reader.read(data)
    }
}

extension SRTStream: HKStream {
    // MARK: IOStreamConvertible
    public var audioSettings: AudioCodecSettings {
        mediaCodec.audioSettings
    }

    public var videoSettings: VideoCodecSettings {
        mediaCodec.videoSettings
    }

    public func setAudioSettings(_ audioSettings: AudioCodecSettings) {
        mediaCodec.audioSettings = audioSettings
    }

    public func setVideoSettings(_ videoSettings: VideoCodecSettings) {
        mediaCodec.videoSettings = videoSettings
    }

    public func setBitrateStorategy(_ bitrateStorategy: (some HKStreamBitRateStrategy)?) {
        self.bitrateStorategy = bitrateStorategy
    }

    public func append(_ sampleBuffer: CMSampleBuffer) {
        switch sampleBuffer.formatDescription?.mediaType {
        case .video?:
            if sampleBuffer.formatDescription?.isCompressed == true {
            } else {
                mediaCodec.append(sampleBuffer)
                outputs.forEach { $0.stream(self, didOutput: sampleBuffer) }
            }
        default:
            break
        }
    }

    public func attachAudioPlayer(_ audioPlayer: AudioPlayer?) {
        Task {
            audioPlayerNode = await audioPlayer?.makePlayerNode()
            await mediaLink.setAudioPlayer(audioPlayerNode)
        }
    }

    public func append(_ buffer: AVAudioBuffer, when: AVAudioTime) {
        guard buffer is AVAudioPCMBuffer else {
            return
        }
        mediaCodec.append(buffer, when: when)
        outputs.forEach { $0.stream(self, didOutput: buffer, when: when) }
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

extension SRTStream: IOMixerOutput {
    // MARK: IOMixerOutput
    nonisolated public func mixer(_ mixer: IOMixer, track: UInt8, didOutput sampleBuffer: CMSampleBuffer) {
        guard track == UInt8.max else {
            return
        }
        Task { await append(sampleBuffer) }
    }

    nonisolated public func mixer(_ mixer: IOMixer, track: UInt8, didOutput buffer: AVAudioPCMBuffer, when: AVAudioTime) {
        guard track == UInt8.max else {
            return
        }
        Task { await append(buffer, when: when) }
    }
}
