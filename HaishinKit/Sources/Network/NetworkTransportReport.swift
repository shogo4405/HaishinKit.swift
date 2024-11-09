import Foundation

/// A structure that represents a network transport bitRate statics.
public struct NetworkTransportReport: Sendable {
    /// The statistics of outgoing queue bytes per second.
    public let queueBytesOut: Int
    /// The statistics of incoming bytes per second.
    public let totalBytesIn: Int
    /// The statistics of outgoing bytes per second.
    public let totalBytesOut: Int

    /// Creates a new instance.
    public init(queueBytesOut: Int, totalBytesIn: Int, totalBytesOut: Int) {
        self.queueBytesOut = queueBytesOut
        self.totalBytesIn = totalBytesIn
        self.totalBytesOut = totalBytesOut
    }
}
