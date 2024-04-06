import Foundation

/// A structure that represents a IOStream's bitRate statics.
public struct IOStreamBitRateStats {
    /// The statistics of outgoing queue bytes per second.
    public let currentQueueBytesOut: Int64
    /// The statistics of incoming bytes per second.
    public let currentBytesInPerSecond: Int32
    /// The statistics of outgoing bytes per second.
    public let currentBytesOutPerSecond: Int32
}

/// A type with a IOStream's bitrate strategy representation.
public protocol IOStreamBitRateStrategyConvertible: AnyObject {
    /// Specifies the stream instance.
    var stream: IOStream? { get set }
    /// The mamimum video bitRate.
    var mamimumVideoBitRate: Int { get }
    /// The mamimum audio bitRate.
    var mamimumAudioBitRate: Int { get }

    /// SetUps the NetBitRateStrategy instance.
    func setUp()
    /// Invoke sufficientBWOccured.
    func sufficientBWOccured(_ stats: IOStreamBitRateStats)
    /// Invoke insufficientBWOccured.
    func insufficientBWOccured(_ stats: IOStreamBitRateStats)
}

/// The IOStreamBitRateStrategy class provides a no operative bitrate storategy.
public final class IOStreamBitRateStrategy: IOStreamBitRateStrategyConvertible {
    public static let shared = IOStreamBitRateStrategy()

    public weak var stream: IOStream?
    public let mamimumVideoBitRate: Int = 0
    public let mamimumAudioBitRate: Int = 0

    public func setUp() {
    }

    public func sufficientBWOccured(_ stats: IOStreamBitRateStats) {
    }

    public func insufficientBWOccured(_ stats: IOStreamBitRateStats) {
    }
}

/// The IOStreamVideoAdaptiveBitRateStrategy class provides an algorithm that focuses on video bitrate control.
public final class IOStreamVideoAdaptiveBitRateStrategy: IOStreamBitRateStrategyConvertible {
    public static let sufficientBWCountsThreshold: Int = 15

    public weak var stream: IOStream?
    public let mamimumVideoBitRate: Int
    public let mamimumAudioBitRate: Int = 0
    private var sufficientBWCounts: Int = 0
    private var zeroBytesOutPerSecondCounts: Int = 0

    public init(mamimumVideoBitrate: Int) {
        self.mamimumVideoBitRate = mamimumVideoBitrate
    }

    public func setUp() {
        zeroBytesOutPerSecondCounts = 0
        stream?.videoSettings.bitRate = mamimumVideoBitRate
    }

    public func sufficientBWOccured(_ stats: IOStreamBitRateStats) {
        guard let stream else {
            return
        }
        if stream.videoSettings.bitRate == mamimumVideoBitRate {
            return
        }
        if Self.sufficientBWCountsThreshold <= sufficientBWCounts {
            let incremental = mamimumVideoBitRate / 10
            stream.videoSettings.bitRate = min(stream.videoSettings.bitRate + incremental, mamimumVideoBitRate)
            sufficientBWCounts = 0
        } else {
            sufficientBWCounts += 1
        }
    }

    public func insufficientBWOccured(_ stats: IOStreamBitRateStats) {
        guard let stream, 0 < stats.currentBytesOutPerSecond else {
            return
        }
        sufficientBWCounts = 0
        if 0 < stats.currentBytesOutPerSecond {
            let bitRate = Int(stats.currentBytesOutPerSecond * 8) / (zeroBytesOutPerSecondCounts + 1)
            stream.videoSettings.bitRate = max(bitRate - stream.audioSettings.bitRate, mamimumVideoBitRate / 10)
            stream.videoSettings.frameInterval = 0.0
            sufficientBWCounts = 0
            zeroBytesOutPerSecondCounts = 0
        } else {
            switch zeroBytesOutPerSecondCounts {
            case 2:
                stream.videoSettings.frameInterval = VideoCodecSettings.frameInterval10
            case 4:
                stream.videoSettings.frameInterval = VideoCodecSettings.frameInterval05
            default:
                break
            }
            zeroBytesOutPerSecondCounts += 1
        }
    }
}
