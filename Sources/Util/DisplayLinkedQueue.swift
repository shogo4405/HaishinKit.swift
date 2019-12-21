import AVFoundation

#if os(macOS)
#else
    typealias DisplayLink = CADisplayLink
#endif

protocol DisplayLinkedQueueDelegate: class {
    func queue(_ buffer: CMSampleBuffer)
    func empty()
}

final class DisplayLinkedQueue: NSObject {
    static let defaultPreferredFramesPerSecond: Int = 0

    var locked: Atomic<Bool> = .init(true)
    var audioDuration: Atomic<Double> = .init(0.0)
    var audioVideoLatency: TimeInterval {
        return audioDuration.value - videoDuration
    }
    weak var delegate: DisplayLinkedQueueDelegate?
    private(set) var videoDuration: TimeInterval = 0.0 {
        didSet {
            if displayLinkTime == 0.0 {
                displayLinkTime = videoDuration
            }
            videoDuration -= displayLinkTime
        }
    }
    private var displayLinkTime: TimeInterval = 0.0
    private(set) var isRunning: Atomic<Bool> = .init(false)
    private var buffer: CircularBuffer<CMSampleBuffer> = .init(256)
    private var displayLink: DisplayLink? {
        didSet {
            oldValue?.invalidate()
            guard let displayLink: DisplayLink = displayLink else {
                return
            }
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
        guard !locked.value else {
            return
        }
        videoDuration = displayLink.timestamp
        guard let first = buffer.first, first.presentationTimeStamp.seconds <= videoDuration else {
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
            self.videoDuration = 0.0
            self.audioDuration.mutate { $0 = 0.0 }
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
