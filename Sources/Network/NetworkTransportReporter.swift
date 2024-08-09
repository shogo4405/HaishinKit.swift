import Foundation

public protocol NetworkTransportReporter: Actor {
    func makeNetworkTransportReport() async -> NetworkTransportReport
}
