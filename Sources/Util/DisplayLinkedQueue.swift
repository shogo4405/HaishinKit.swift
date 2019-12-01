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
    var audioDuration: Atomic<Double> = .init(0.0)
    weak var delegate: DisplayLinkedQueueDelegate?
    private(set) var isRunning: Atomic<Bool> = .init(false)
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
        } else {
            guard 0 < buffer.duration.seconds else { return }
        }
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
        if first.presentationTimeStamp.seconds - clockTime <= max(displayLink.timestamp - mediaTime, audioDuration.value) {
            buffer.removeFirst()
            if buffer.isEmpty {
                delegate?.empty()
            }
            if hasNext(displayLink) {
                update(displayLink: displayLink)
            } else {
                delegate?.queue(first)
            }
        }
    }

    private func hasNext(_ displayLink: DisplayLink) -> Bool {
        guard let first: CMSampleBuffer = buffer.first else {
            return false
        }
        return first.presentationTimeStamp.seconds - clockTime <= max(displayLink.timestamp - mediaTime, audioDuration.value)
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
