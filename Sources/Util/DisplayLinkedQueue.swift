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
    var locked: Atomic<Bool> = .init(true)
    var isRunning: Atomic<Bool> = .init(false)
    var bufferTime: TimeInterval = 0.0 // sec
    weak var delegate: DisplayLinkedQueueDelegate?
    private(set) var duration: TimeInterval = 0
    private var buffer: CircularBuffer<CMSampleBuffer> = .init(256)
    private var mediaTime: CFTimeInterval = 0
    private var clockTime: Double = 0.0
    private var displayLink: DisplayLink? {
        didSet {
            oldValue?.invalidate()
            guard let displayLink: DisplayLink = displayLink else {
                return
            }
            displayLink.frameInterval = 1
            displayLink.add(to: .main, forMode: .common)
        }
    }
    private let lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.DisplayLinkedQueue.lock")

    func enqueue(_ buffer: CMSampleBuffer) {
        guard buffer.presentationTimeStamp != .invalid else { return }
        if mediaTime == 0 && clockTime == 0 && self.buffer.isEmpty {
            delegate?.queue(buffer)
        }
        duration += buffer.duration.seconds
        self.buffer.append(buffer)
    }

    @objc
    private func update(displayLink: DisplayLink) {
        guard let first: CMSampleBuffer = buffer.first, !locked.value else {
            return
        }
        if mediaTime == 0 {
            mediaTime = displayLink.timestamp
        }
        if clockTime == 0 {
            clockTime = first.presentationTimeStamp.seconds
        }
        if first.presentationTimeStamp.seconds - clockTime <= displayLink.timestamp - mediaTime {
            buffer.removeFirst()
            if buffer.isEmpty {
                delegate?.empty()
            }
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
            self.mediaTime = 0
            self.clockTime = 0
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
