import Foundation

public protocol NetworkTransportReporter: Actor {
    func makeNetworkMonitor() async -> NetworkMonitor
    func makeNetworkTransportReport() async -> NetworkTransportReport
}
