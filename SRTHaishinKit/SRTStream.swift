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
    private var audioPlayerNode: AudioPlayerNode?
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
                    append(buffer)
                }
            }
            Task {
                for await buffer in mediaCodec.audio where mediaCodec.isRunning {
                    append(buffer.0, when: buffer.1)
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
                await audioPlayerNode?.startRunning()
                for await audio in mediaCodec.audio where mediaCodec.isRunning {
                    append(audio.0, when: audio.1)
                }
            }
            Task {
                for try await buffer in reader.output where mediaCodec.isRunning {
                    append(buffer.1)
                }
            }
            Task {
                for await video in await mediaLink.dequeue where mediaCodec.isRunning {
                    append(video)
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
    // MARK: HKStream
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
        guard sampleBuffer.formatDescription?.mediaType == .video else {
            return
        }
        switch readyState {
        case .publishing:
            if sampleBuffer.formatDescription?.isCompressed == true {
                writer.append(sampleBuffer)
            } else {
                mediaCodec.append(sampleBuffer)
            }
        default:
            break
        }
        if sampleBuffer.formatDescription?.isCompressed == false {
            outputs.forEach { $0.stream(self, didOutput: sampleBuffer) }
        }
    }

    public func append(_ audioBuffer: AVAudioBuffer, when: AVAudioTime) {
        switch readyState {
        case .playing:
            switch audioBuffer {
            case let audioBuffer as AVAudioPCMBuffer:
                Task { await audioPlayerNode?.enqueue(audioBuffer, when: when) }
            default:
                break
            }
        case .publishing:
            switch audioBuffer {
            case let audioBuffer as AVAudioPCMBuffer:
                mediaCodec.append(audioBuffer, when: when)
            case let audioBuffer as AVAudioCompressedBuffer:
                writer.append(audioBuffer, when: when)
            default:
                break
            }
        default:
            break
        }
        if audioBuffer is AVAudioPCMBuffer {
            outputs.forEach { $0.stream(self, didOutput: audioBuffer, when: when) }
        }
    }

    public func attachAudioPlayer(_ audioPlayer: AudioPlayer?) {
        Task {
            audioPlayerNode = await audioPlayer?.makePlayerNode()
            await mediaLink.setAudioPlayer(audioPlayerNode)
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
