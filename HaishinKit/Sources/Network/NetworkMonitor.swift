import Foundation

/// An objec thatt provides the RTMPConnection, SRTConnection's monitoring events.
public final actor NetworkMonitor {
    /// The error domain codes.
    public enum Error: Swift.Error {
        /// An invalid internal stare.
        case invalidState
    }

    /// An asynchronous sequence for network monitoring  event.
    public var event: AsyncStream<NetworkMonitorEvent> {
        AsyncStream { continuation in
            self.continuation = continuation
        }
    }

    public private(set) var isRunning = false
    private var timer: Task<Void, Never>? {
        didSet {
            oldValue?.cancel()
        }
    }
    private var measureInterval = 3
    private var currentBytesInPerSecond = 0
    private var currentBytesOutPerSecond = 0
    private var previousTotalBytesIn = 0
    private var previousTotalBytesOut = 0
    private var previousQueueBytesOut: [Int] = []
    private var continuation: AsyncStream<NetworkMonitorEvent>.Continuation? {
        didSet {
            oldValue?.finish()
        }
    }
    private weak var reporter: (any NetworkTransportReporter)?

    /// Creates a new instance.
    public init(_ reporter: some NetworkTransportReporter) {
        self.reporter = reporter
    }

    private func collect() async throws -> NetworkMonitorEvent {
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
            totalBytesIn: totalBytesIn,
            totalBytesOut: totalBytesOut,
            currentQueueBytesOut: queueBytesOut,
            currentBytesInPerSecond: currentBytesInPerSecond,
            currentBytesOutPerSecond: currentBytesOutPerSecond
        )
        if measureInterval <= previousQueueBytesOut.count {
            defer {
                previousQueueBytesOut.removeFirst()
            }
            var total = 0
            for i in 0..<previousQueueBytesOut.count - 1 where previousQueueBytesOut[i] < previousQueueBytesOut[i + 1] {
                total += 1
            }
            if total == measureInterval - 1 {
                return .publishInsufficientBWOccured(report: eventReport)
            } else if total == 0 {
                return .status(report: eventReport)
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
        timer = Task {
            let timer = AsyncStream {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            for await _ in timer {
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
        timer = nil
        continuation = nil
    }
}
