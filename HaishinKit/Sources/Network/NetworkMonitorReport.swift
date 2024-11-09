import Foundation

/// The struct represents a network statistics.
public struct NetworkMonitorReport: Sendable {
    /// The statistics of total incoming bytes.
    public let totalBytesIn: Int
    /// The statistics of total outgoing bytes.
    public let totalBytesOut: Int
    /// The statistics of outgoing queue bytes per second.
    public let currentQueueBytesOut: Int
    /// The statistics of incoming bytes per second.
    public let currentBytesInPerSecond: Int
    /// The statistics of outgoing bytes per second.
    public let currentBytesOutPerSecond: Int
}
