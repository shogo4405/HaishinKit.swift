import Foundation

public enum NetworkMonitorEvent: Sendable {
    case status(report: NetworkMonitorReport)
    case publishInsufficientBWOccured(report: NetworkMonitorReport)
    case publishSufficientBWOccured(report: NetworkMonitorReport)
}
