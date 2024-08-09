import Foundation

/// A type with a network bitrate strategy representation.
public protocol NetworkBitRateStrategy: Sendable {
    /// The mamimum video bitRate.
    var mamimumVideoBitRate: Int { get }
    /// The mamimum audio bitRate.
    var mamimumAudioBitRate: Int { get }

    func execute(_ event: NetworkMonitorEvent, stream: some IOStream)
}
