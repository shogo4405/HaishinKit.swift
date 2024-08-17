import Foundation

/// A type that represents a factory of network monitor object.
public protocol NetworkTransportReporter: Actor {
    /// Makes a network monitor.
    func makeNetworkMonitor() async -> NetworkMonitor
    /// Makes a network transport report.
    func makeNetworkTransportReport() async -> NetworkTransportReport
}
