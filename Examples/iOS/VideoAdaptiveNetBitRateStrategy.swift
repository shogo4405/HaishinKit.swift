import Foundation

public final class VideoAdaptiveNetBitRateStrategy: NetBitRateStrategyConvertible {
    public weak var stream: NetStream?
    public let mamimumVideoBitRate: Int
    public let mamimumAudioBitRate: Int = 0
    private var zeroBytesOutPerSecondCounts: Int = 0

    public init(mamimumVideoBitrate: Int) {
        self.mamimumVideoBitRate = mamimumVideoBitrate
    }

    public func setUp() {
        zeroBytesOutPerSecondCounts = 0
        stream?.videoSettings.bitRate = mamimumVideoBitRate
    }

    public func sufficientBWOccured(_ stats: NetBitRateStats) {
        guard let stream else {
            return
        }
        stream.videoSettings.bitRate = min(stream.videoSettings.bitRate + 64 * 1000, mamimumVideoBitRate)
    }

    public func insufficientBWOccured(_ stats: NetBitRateStats) {
        guard let stream, 0 < stats.currentBytesOutPerSecond else {
            return
        }
        if 0 < stats.currentBytesOutPerSecond {
            let bitRate = Int(stats.currentBytesOutPerSecond * 8) / (zeroBytesOutPerSecondCounts + 1)
            stream.videoSettings.bitRate = max(bitRate - stream.audioSettings.bitRate, 64 * 1000)
            zeroBytesOutPerSecondCounts = 0
        } else {
            zeroBytesOutPerSecondCounts += 1
        }
    }
}
