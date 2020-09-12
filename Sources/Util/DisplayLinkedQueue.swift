import AVFoundation

#if os(macOS)
#else
    typealias DisplayLink = CADisplayLink
#endif

protocol DisplayLinkedQueueDelegate: class {
    func queue(_ buffer: CMSampleBuffer)
    func empty()
}

protocol DisplayLinkedQueueClockReference: class {
    var duration: TimeInterval { get }
}

final class DisplayLinkedQueue: NSObject {
    static let defaultPreferredFramesPerSecond = 0

    var isPaused: Bool {
        get { displayLink?.isPaused ?? false }
        set { displayLink?.isPaused = newValue }
    }
    var duration: TimeInterval {
        (displayLink?.timestamp ?? 0.0) - timestamp
    }
    weak var delegate: DisplayLinkedQueueDelegate?
    weak var clockReference: DisplayLinkedQueueClockReference?
    private var timestamp: TimeInterval = 0.0
    private var buffer: CircularBuffer<CMSampleBuffer> = .init(256)
    private var displayLink: DisplayLink? {
        didSet {
            oldValue?.invalidate()
            guard let displayLink = displayLink else {
                return
            }
            displayLink.isPaused = true
            if #available(iOS 10.0, tvOS 10.0, *) {
                displayLink.preferredFramesPerSecond = DisplayLinkedQueue.defaultPreferredFramesPerSecond
            } else {
                displayLink.frameInterval = 1
            }
            displayLink.add(to: .main, forMode: .common)
        }
    }
    private let lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.DisplayLinkedQueue.lock")
    private(set) var isRunning: Atomic<Bool> = .init(false)

    func enqueue(_ buffer: CMSampleBuffer) {
        guard buffer.presentationTimeStamp != .invalid else {
            return
        }
        if self.buffer.isEmpty {
            delegate?.queue(buffer)
        }
        _ = self.buffer.append(buffer)
    }

    @objc
    private func update(displayLink: DisplayLink) {
        if timestamp == 0.0 {
            timestamp = displayLink.timestamp
        }
        guard let first = buffer.first else {
            return
        }
        defer {
            if buffer.isEmpty {
                delegate?.empty()
            }
        }
        let current = clockReference?.duration ?? duration
        let targetTimestamp = first.presentationTimeStamp.seconds + first.duration.seconds
        if targetTimestamp < current {
            buffer.removeFirst()
            update(displayLink: displayLink)
            return
        }
        if first.presentationTimeStamp.seconds <= current && current <= targetTimestamp {
            buffer.removeFirst()
            delegate?.queue(first)
        }
    }
}

extension DisplayLinkedQueue: Running {
    // MARK: Running
    func startRunning() {
        lockQueue.async {
            guard !self.isRunning.value else {
                return
            }
            self.timestamp = 0.0
            self.displayLink = DisplayLink(target: self, selector: #selector(self.update(displayLink:)))
            self.isRunning.mutate { $0 = true }
        }
    }

    func stopRunning() {
        lockQueue.async {
            guard self.isRunning.value else {
                return
            }
            self.displayLink = nil
            self.clockReference = nil
            self.buffer.removeAll()
            self.isRunning.mutate { $0 = false }
        }
    }
}
