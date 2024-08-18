import AVFoundation
import Foundation

/// An actor that provides a stream playback feature.
public final actor HKStreamPlayer {
    public private(set) var isRunning = false
    private lazy var mediaLink = MediaLink()
    private lazy var audioCodec = AudioCodec()
    private lazy var videoCodec = VideoCodec()
    private weak var stream: (any HKStream)?
    private var audioPlayerNode: AudioPlayerNode?

    /// Creates a new instance.
    public init(_ stream: some HKStream) {
        self.stream = stream
    }

    /// Appends a sample buffer for playback.
    public func append(_ buffer: CMSampleBuffer) {
        switch buffer.formatDescription?.mediaType {
        case .audio:
            audioCodec.append(buffer)
        case .video:
            videoCodec.append(buffer)
        default:
            break
        }
    }

    /// Appends an audio buffer for playback.
    public func append(_ buffer: AVAudioBuffer, when: AVAudioTime) {
        audioCodec.append(buffer, when: when)
    }

    /// Attaches an audio player.
    public func attachAudioPlayer(_ audioPlayer: AudioPlayer?) {
        Task {
            audioPlayerNode = await audioPlayer?.makePlayerNode()
            await mediaLink.setAudioPlayer(audioPlayerNode)
        }
    }
}

extension HKStreamPlayer: AsyncRunner {
    // MARK: AsyncRunner
    public func startRunning() {
        guard !isRunning else {
            return
        }
        audioCodec.settings.format = .pcm
        videoCodec.startRunning()
        audioCodec.startRunning()
        isRunning = true
        Task {
            await mediaLink.startRunning()
            for await video in await mediaLink.dequeue where await mediaLink.isRunning {
                await stream?.append(video)
            }
        }
        Task {
            do {
                for try await video in videoCodec.outputStream where videoCodec.isRunning {
                    await mediaLink.enqueue(video)
                }
            } catch {
                logger.error(error)
            }
        }
        Task {
            await audioPlayerNode?.startRunning()
            for await audio in audioCodec.outputStream where audioCodec.isRunning {
                await audioPlayerNode?.enqueue(audio.0, when: audio.1)
                await stream?.append(audio.0, when: audio.1)
            }
        }
    }

    public func stopRunning() {
        guard isRunning else {
            return
        }
        videoCodec.stopRunning()
        audioCodec.stopRunning()
        Task { await mediaLink.stopRunning() }
        Task { await audioPlayerNode?.stopRunning() }
        isRunning = false
    }
}

extension HKStreamPlayer {
    func append(_ message: RTMPVideoMessage, presentationTimeStamp: CMTime, formatDesciption: CMFormatDescription?) {
        guard let buffer = message.makeSampleBuffer(presentationTimeStamp, formatDesciption: formatDesciption) else {
            return
        }
        append(buffer)
    }
}
