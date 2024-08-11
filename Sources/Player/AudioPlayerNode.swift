@preconcurrency import AVFoundation
import Foundation

final actor AudioPlayerNode {
    var currentTime: TimeInterval {
        if playerNode.isPlaying {
            guard
                let nodeTime = playerNode.lastRenderTime,
                let playerTime = playerNode.playerTime(forNodeTime: nodeTime) else {
                return 0.0
            }
            return TimeInterval(playerTime.sampleTime) / playerTime.sampleRate
        }
        return 0.0
    }
    private(set) var isPaused = false
    private(set) var isRunning = false
    private let playerNode: AVAudioPlayerNode
    private var audioTime = IOAudioTime()
    private var scheduledAudioBuffers: Int = 0
    private var isBuffering = true
    private weak var player: AudioPlayer?
    private var format: AVAudioFormat? {
        didSet {
            Task { [format] in
                await player?.connect(self, format: format)
            }
        }
    }

    init(player: AudioPlayer, playerNode: AVAudioPlayerNode) {
        self.playerNode = playerNode
    }

    func enqueue(_ audioBuffer: AVAudioBuffer, when: AVAudioTime) {
        guard let audioBuffer = audioBuffer as? AVAudioPCMBuffer else {
            return
        }

        if format != audioBuffer.format {
            format = audioBuffer.format
        }

        if !audioTime.hasAnchor {
            audioTime.anchor(playerNode.lastRenderTime ?? AVAudioTime(hostTime: 0))
        }

        scheduledAudioBuffers += 1
        if !isPaused && !playerNode.isPlaying && 10 <= scheduledAudioBuffers {
            playerNode.play()
        }

        Task {
            audioTime.advanced(Int64(audioBuffer.frameLength))
            await playerNode.scheduleBuffer(audioBuffer, at: audioTime.at)
            scheduledAudioBuffers -= 1
            if scheduledAudioBuffers == 0 {
                isBuffering = true
            }
        }
    }
}

extension AudioPlayerNode: AsyncRunner {
    func startRunning() {
        guard !isRunning else {
            return
        }
        scheduledAudioBuffers = 0
        isRunning = true
    }

    func stopRunning() {
        guard isRunning else {
            return
        }
        if playerNode.isPlaying {
            playerNode.stop()
            playerNode.reset()
        }
        playerNode.stop()
        audioTime.reset()
        format = nil
        isRunning = false
    }
}

extension AudioPlayerNode: Hashable {
    // MARK: Hashable
    nonisolated public static func == (lhs: AudioPlayerNode, rhs: AudioPlayerNode) -> Bool {
        lhs === rhs
    }

    nonisolated public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
