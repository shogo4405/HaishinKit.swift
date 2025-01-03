@preconcurrency import AVFoundation
import Combine
import Foundation
import HaishinKit
import libsrt

/// An actor that provides the interface to control a one-way channel over a SRTConnection.
public actor SRTStream {
    @Published public private(set) var readyState: HKStreamReadyState = .idle
    public private(set) var videoTrackId: UInt8? = UInt8.max
    public private(set) var audioTrackId: UInt8? = UInt8.max
    private var name: String?
    private var action: (() async -> Void)?
    private var outputs: [any HKStreamOutput] = []
    private var bitrateStorategy: (any HKStreamBitRateStrategy)?
    private lazy var writer = TSWriter()
    private lazy var reader = TSReader()
    private lazy var incoming = HKIncomingStream(self)
    private lazy var outgoing = HKOutgoingStream()
    private weak var connection: SRTConnection?

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
                await close()
            default:
                break
            }
            return
        }
        if await connection?.connected == true {
            readyState = .publishing
            outgoing.startRunning()
            if outgoing.videoInputFormat != nil {
                writer.expectedMedias.insert(.video)
            }
            if outgoing.audioInputFormat != nil {
                writer.expectedMedias.insert(.audio)
            }
            Task {
                for await buffer in outgoing.videoOutputStream {
                    append(buffer)
                }
            }
            Task {
                for await buffer in outgoing.audioOutputStream {
                    append(buffer.0, when: buffer.1)
                }
            }
            Task {
                for await buffer in outgoing.videoInputStream {
                    outgoing.append(video: buffer)
                }
            }
            Task {
                for await data in writer.output {
                    await connection?.send(data)
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
                await close()
            default:
                break
            }
            return
        }
        if await connection?.connected == true {
            await connection?.recv()
            Task {
                await incoming.startRunning()
                for await buffer in reader.output {
                    await incoming.append(buffer.1)
                }
            }
            readyState = .playing
        } else {
            action = { [weak self] in await self?.play(name) }
        }
    }

    /// Stops playing or publishing and makes available other uses.
    public func close() async {
        guard readyState != .idle else {
            return
        }
        writer.clear()
        reader.clear()
        outgoing.stopRunning()
        Task { await incoming.stopRunning() }
        readyState = .idle
    }

    func doInput(_ data: Data) {
        _ = reader.read(data)
    }
}

extension SRTStream: HKStream {
    // MARK: HKStream
    public var soundTransform: SoundTransform? {
        get async {
            await incoming.soundTransfrom
        }
    }

    public func setSoundTransform(_ soundTransform: SoundTransform) async {
        await incoming.setSoundTransform(soundTransform)
    }

    public var audioSettings: AudioCodecSettings {
        outgoing.audioSettings
    }

    public var videoSettings: VideoCodecSettings {
        outgoing.videoSettings
    }

    public func setAudioSettings(_ audioSettings: AudioCodecSettings) {
        outgoing.audioSettings = audioSettings
    }

    public func setVideoSettings(_ videoSettings: VideoCodecSettings) {
        outgoing.videoSettings = videoSettings
    }

    public func setBitrateStorategy(_ bitrateStorategy: (some HKStreamBitRateStrategy)?) {
        self.bitrateStorategy = bitrateStorategy
    }

    public func setVideoInputBufferCounts(_ videoInputBufferCounts: Int) {
        outgoing.videoInputBufferCounts = videoInputBufferCounts
    }

    public func append(_ sampleBuffer: CMSampleBuffer) {
        switch sampleBuffer.formatDescription?.mediaType {
        case .video:
            if sampleBuffer.formatDescription?.isCompressed == true {
                writer.videoFormat = sampleBuffer.formatDescription
                writer.append(sampleBuffer)
            } else {
                outgoing.append(sampleBuffer)
                outputs.forEach { $0.stream(self, didOutput: sampleBuffer) }
            }
        default:
            break
        }
    }

    public func append(_ audioBuffer: AVAudioBuffer, when: AVAudioTime) {
        switch audioBuffer {
        case let audioBuffer as AVAudioPCMBuffer:
            outgoing.append(audioBuffer, when: when)
            outputs.forEach { $0.stream(self, didOutput: audioBuffer, when: when) }
        case let audioBuffer as AVAudioCompressedBuffer:
            writer.audioFormat = audioBuffer.format
            writer.append(audioBuffer, when: when)
        default:
            break
        }
    }

    public func attachAudioPlayer(_ audioPlayer: AudioPlayer?) async {
        await incoming.attachAudioPlayer(audioPlayer)
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

    public func dispatch(_ event: NetworkMonitorEvent) async {
        await bitrateStorategy?.adjustBitrate(event, stream: self)
    }
}

extension SRTStream: MediaMixerOutput {
    // MARK: MediaMixerOutput
    public func selectTrack(_ id: UInt8?, mediaType: CMFormatDescription.MediaType) {
        switch mediaType {
        case .audio:
            audioTrackId = id
        case .video:
            videoTrackId = id
        default:
            break
        }
    }

    nonisolated public func mixer(_ mixer: MediaMixer, didOutput sampleBuffer: CMSampleBuffer) {
        Task { await append(sampleBuffer) }
    }

    nonisolated public func mixer(_ mixer: MediaMixer, didOutput buffer: AVAudioPCMBuffer, when: AVAudioTime) {
        Task { await append(buffer, when: when) }
    }
}
