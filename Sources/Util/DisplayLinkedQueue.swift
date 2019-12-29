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
        get { return displayLink?.isPaused ?? false }
        set { displayLink?.isPaused = newValue }
    }
    var duration: TimeInterval {
        (displayLink?.timestamp ?? 0.0) - displayLinkTime
    }
    weak var delegate: DisplayLinkedQueueDelegate?
    weak var clockReference: DisplayLinkedQueueClockReference?
    private var displayLinkTime: TimeInterval = 0.0
    private(set) var isRunning: Atomic<Bool> = .init(false)
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

    func enqueue(_ buffer: CMSampleBuffer) {
        guard buffer.presentationTimeStamp != .invalid else { return }
        if self.buffer.isEmpty {
            delegate?.queue(buffer)
        } else {
            guard 0 < buffer.duration.seconds else { return }
        }
        self.buffer.append(buffer)
    }

    @objc
    private func update(displayLink: DisplayLink) {
        if displayLinkTime == 0.0 {
            displayLinkTime = displayLink.timestamp
        }
        guard let first = buffer.first, first.presentationTimeStamp.seconds <= duration else {
            return
        }
        buffer.removeFirst()
        if buffer.isEmpty {
            delegate?.empty()
        }
        delegate?.queue(first)
    }
}

extension DisplayLinkedQueue: Running {
    // MARK: Running
    func startRunning() {
        lockQueue.async {
            guard !self.isRunning.value else {
                return
            }
            self.displayLinkTime = 0.0
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
            self.buffer.removeAll()
            self.isRunning.mutate { $0 = false }
        }
    }
}
