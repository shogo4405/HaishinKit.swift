import Foundation

public struct NetworkTransportReport: Sendable {
    public let queueBytesOut: Int
    public let totalBytesIn: Int
    public let totalBytesOut: Int
}
