import Foundation

public struct NetworkMonitorReport: Sendable {
    /// The statistics of outgoing queue bytes per second.
    public let currentQueueBytesOut: Int
    /// The statistics of incoming bytes per second.
    public let currentBytesInPerSecond: Int
    /// The statistics of outgoing bytes per second.
    public let currentBytesOutPerSecond: Int
    public let totalBytesIn: Int
}
