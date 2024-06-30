import Foundation

public final actor NetworkMonitor {
    public enum Error: Swift.Error {
        case invalidState
    }

    public var event: AsyncStream<NetworkMonitorEvent> {
        let (stream, continuation) = AsyncStream<NetworkMonitorEvent>.makeStream()
        self.continuation = continuation
        return stream
    }

    public private(set) var isRunning = false
    private var measureInterval = 3
    private var currentBytesInPerSecond = 0
    private var currentBytesOutPerSecond = 0
    private var previousTotalBytesIn = 0
    private var previousTotalBytesOut = 0
    private var previousQueueBytesOut: [Int] = []
    private var continuation: AsyncStream<NetworkMonitorEvent>.Continuation?
    private weak var reporter: (any NetworkTransportReporter)?

    public init(_ reporter: some NetworkTransportReporter) {
        self.reporter = reporter
    }

    public func collect() async throws -> NetworkMonitorEvent {
        guard let report = await reporter?.makeNetworkTransportReport() else {
            throw Error.invalidState
        }
        let totalBytesIn = report.totalBytesIn
        let totalBytesOut = report.totalBytesOut
        let queueBytesOut = report.queueBytesOut
        currentBytesInPerSecond = totalBytesIn - previousTotalBytesIn
        currentBytesOutPerSecond = totalBytesOut - previousTotalBytesOut
        previousTotalBytesIn = totalBytesIn
        previousTotalBytesOut = totalBytesOut
        previousQueueBytesOut.append(queueBytesOut)
        let eventReport = NetworkMonitorReport(
            currentQueueBytesOut: queueBytesOut,
            currentBytesInPerSecond: currentBytesInPerSecond,
            currentBytesOutPerSecond: currentBytesOutPerSecond,
            totalBytesIn: totalBytesIn
        )
        defer {
            previousQueueBytesOut.removeFirst()
        }
        if measureInterval <= previousQueueBytesOut.count {
            var total = 0
            for i in 0..<previousQueueBytesOut.count - 1 where previousQueueBytesOut[i] < previousQueueBytesOut[i + 1] {
                total += 1
            }
            if total == measureInterval - 1 {
                return .publishInsufficientBWOccured(report: eventReport)
            } else if total == 0 {
                return .publishSufficientBWOccured(report: eventReport)
            }
        }
        return .status(report: eventReport)
    }
}

extension NetworkMonitor: AsyncRunner {
    // MARK: AsyncRunner
    public func startRunning() {
        guard !isRunning else {
            return
        }
        isRunning = true
        let timer = AsyncStream {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
        Task {
            for await _ in timer where isRunning {
                do {
                    let event = try await collect()
                    continuation?.yield(event)
                } catch {
                    continuation?.finish()
                }
            }
        }
    }

    public func stopRunning() {
        guard isRunning else {
            return
        }
        isRunning = false
    }
}

public struct NetworkMonitorReport: Sendable {
    /// The statistics of outgoing queue bytes per second.
    public let currentQueueBytesOut: Int
    /// The statistics of incoming bytes per second.
    public let currentBytesInPerSecond: Int
    /// The statistics of outgoing bytes per second.
    public let currentBytesOutPerSecond: Int
    public let totalBytesIn: Int
}

public enum NetworkMonitorEvent: Sendable {
    case status(report: NetworkMonitorReport)
    case publishInsufficientBWOccured(report: NetworkMonitorReport)
    case publishSufficientBWOccured(report: NetworkMonitorReport)
}
