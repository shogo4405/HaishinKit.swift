@preconcurrency import AVFoundation

/// An object that provides the interface to control audio playback.
public final actor AudioPlayer {
    private var connected: [AudioPlayerNode: Bool] = [:]
    private var audioEngine: AVAudioEngine?
    private var playerNodes: [AudioPlayerNode: AVAudioPlayerNode] = [:]

    /// Create an audio player object.
    public init(audioEngine: AVAudioEngine) {
        self.audioEngine = audioEngine
    }

    public func isConnected(_ playerNode: AudioPlayerNode) -> Bool {
        return connected[playerNode] == true
    }

    public func connect(_ playerNode: AudioPlayerNode, format: AVAudioFormat?) {
        guard let audioEngine, let avPlayerNode = playerNodes[playerNode] else {
            return
        }
        audioEngine.connect(avPlayerNode, to: audioEngine.outputNode, format: format)
        if !audioEngine.isRunning {
            try? audioEngine.start()
        }
        connected[playerNode] = true
    }

    public func makePlayerNode() -> AudioPlayerNode {
        let avAudioPlayerNode = AVAudioPlayerNode()
        audioEngine?.attach(avAudioPlayerNode)
        let playerNode = AudioPlayerNode(player: self, playerNode: avAudioPlayerNode)
        playerNodes[playerNode] = avAudioPlayerNode
        return playerNode
    }
}
