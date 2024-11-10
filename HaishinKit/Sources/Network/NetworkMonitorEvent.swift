import Foundation

/// An enumeration that indicate the network monitor event.
public enum NetworkMonitorEvent: Sendable {
    /// To update statistics.
    case status(report: NetworkMonitorReport)
    /// To publish sufficient bandwidth occured.
    case publishInsufficientBWOccured(report: NetworkMonitorReport)
    /// To reset  statistics.
    case reset
}
