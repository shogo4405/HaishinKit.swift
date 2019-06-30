import AVFoundation

#if os(macOS)
    import CoreVideo

    final class DisplayLink: NSObject {
        var frameInterval: Int = 0
        private(set) var timestamp: CFTimeInterval = 0
        private var displayLink: CVDisplayLink?
        private weak var delegate: NSObject?
        private var selector: Selector?
        private var status: CVReturn = 0

        private var callback: CVDisplayLinkOutputCallback = { (displayLink: CVDisplayLink, inNow: UnsafePointer<CVTimeStamp>, inOutputTIme: UnsafePointer<CVTimeStamp>, flagsIn: CVOptionFlags, flgasOut: UnsafeMutablePointer<CVOptionFlags>, displayLinkContext: UnsafeMutableRawPointer?) -> CVReturn in
            let displayLink: DisplayLink = Unmanaged<DisplayLink>.fromOpaque(displayLinkContext!).takeUnretainedValue()
            displayLink.timestamp = Double(inNow.pointee.videoTime) / Double(inNow.pointee.videoTimeScale)
            _ = displayLink.delegate?.perform(displayLink.selector, with: displayLink)
            return 0
        }

        init(target: NSObject, selector sel: Selector) {
            super.init()
            status = CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
            guard let displayLink: CVDisplayLink = displayLink else {
                return
            }
            self.delegate = target
            self.selector = sel
            CVDisplayLinkSetOutputCallback(displayLink, callback, Unmanaged.passUnretained(self).toOpaque())
        }

        func add(to runloop: RunLoop, forMode mode: RunLoop.Mode) {
            guard let displayLink: CVDisplayLink = displayLink else {
                return
            }
            status = CVDisplayLinkStart(displayLink)
        }

        func invalidate() {
            guard let displayLink: CVDisplayLink = displayLink else {
                return
            }
            status = CVDisplayLinkStop(displayLink)
        }
    }
#else
    typealias DisplayLink = CADisplayLink
#endif

protocol DisplayLinkedQueueDelegate: class {
    func queue(_ buffer: CMSampleBuffer)
}

final class DisplayLinkedQueue: NSObject {
    var locked: Atomic<Bool> = .init(true)
    var isRunning: Bool = false
    var bufferTime: TimeInterval = 0.1 // sec
    weak var delegate: DisplayLinkedQueueDelegate?
    private(set) var duration: TimeInterval = 0
    private var isReady: Bool = false
    private var buffers: [CMSampleBuffer] = []
    private var mediaTime: CFTimeInterval = 0
    private var clockTime: Double = 0.0
    private var displayLink: DisplayLink? {
        didSet {
            oldValue?.invalidate()
            guard let displayLink: DisplayLink = displayLink else {
                return
            }
            displayLink.frameInterval = 1
            displayLink.add(to: .main, forMode: RunLoop.Mode.common)
        }
    }
    private let lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.DisplayLinkedQueue.lock")

    func enqueue(_ buffer: CMSampleBuffer) {
        lockQueue.async {
            if self.mediaTime == 0 && self.clockTime == 0 && self.buffers.isEmpty {
                self.delegate?.queue(buffer)
            }
            self.duration += buffer.duration.seconds
            self.buffers.append(buffer)
            if !self.isReady {
                self.isReady = self.duration <= self.bufferTime && !self.locked.value
            }
        }
    }

    @objc
    private func update(displayLink: DisplayLink) {
        guard let first: CMSampleBuffer = buffers.first, isReady else {
            return
        }
        if mediaTime == 0 {
            mediaTime = displayLink.timestamp
        }
        if clockTime == 0 {
            clockTime = first.presentationTimeStamp.seconds
        }
        if first.presentationTimeStamp.seconds - clockTime <= displayLink.timestamp - mediaTime {
            lockQueue.async {
                self.buffers.removeFirst()
            }
            delegate?.queue(first)
        }
    }
}

extension DisplayLinkedQueue: Running {
    // MARK: Running
    func startRunning() {
        lockQueue.async {
            guard !self.isRunning else {
                return
            }
            self.mediaTime = 0
            self.clockTime = 0
            self.displayLink = DisplayLink(target: self, selector: #selector(self.update(displayLink:)))
            self.isRunning = true
        }
    }

    func stopRunning() {
        lockQueue.async {
            guard self.isRunning else {
                return
            }
            self.displayLink = nil
            self.buffers.removeAll()
            self.isRunning = false
        }
    }
}
