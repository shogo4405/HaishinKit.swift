import Foundation

/// A structure that represents a NetStream's bitRate statics.
public struct NetBitRateStats {
    public let currentQueueBytesOut: Int64
    public let currentBytesInPerSecond: Int32
    public let currentBytesOutPerSecond: Int32
}

/// A type with a NetStream's bitrate strategy representation.
public protocol NetBitRateStrategyConvertible: AnyObject {
    var stream: NetStream? { get set }
    var mamimumVideoBitRate: Int { get }
    var mamimumAudioBitRate: Int { get }

    func setUp()
    func sufficientBWOccured(_ stats: NetBitRateStats)
    func insufficientBWOccured(_ stats: NetBitRateStats)
}

/// The NetBitRateStrategy class provides a no operative bitrate storategy.
public final class NetBitRateStrategy: NetBitRateStrategyConvertible {
    public static let shared = NetBitRateStrategy()

    public weak var stream: NetStream?
    public let mamimumVideoBitRate: Int = 0
    public let mamimumAudioBitRate: Int = 0

    public func setUp() {
    }

    public func sufficientBWOccured(_ stats: NetBitRateStats) {
    }

    public func insufficientBWOccured(_ stats: NetBitRateStats) {
    }
}
