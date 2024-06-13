import Foundation

#if os(macOS)

import CoreVideo
import Foundation

// swiftlint:disable attributes

final class DisplayLink: NSObject {
    private static let preferredFramesPerSecond = 0

    var isPaused = false {
        didSet {
            guard let displayLink = displayLink, oldValue != isPaused else {
                return
            }
            if isPaused {
                CVDisplayLinkStop(displayLink)
            } else {
                CVDisplayLinkStart(displayLink)
            }
        }
    }
    var preferredFramesPerSecond = DisplayLink.preferredFramesPerSecond {
        didSet {
            guard preferredFramesPerSecond != oldValue else {
                return
            }
            frameInterval = 1.0 / Double(preferredFramesPerSecond)
        }
    }
    private(set) var duration = 0.0
    private(set) var timestamp: CFTimeInterval = 0
    private var selector: Selector?
    private var displayLink: CVDisplayLink?
    private var frameInterval = 0.0
    private weak var delegate: NSObject?

    deinit {
        selector = nil
    }

    init(target: NSObject, selector sel: Selector) {
        super.init()
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        guard let displayLink = displayLink else {
            return
        }
        self.delegate = target
        self.selector = sel
        CVDisplayLinkSetOutputHandler(displayLink) { [weak self] _, inNow, _, _, _ -> CVReturn in
            guard let self else {
                return kCVReturnSuccess
            }
            self.duration += inNow.pointee.duration
            if frameInterval == 0 || frameInterval < inNow.pointee.timestamp - self.timestamp {
                self.timestamp = inNow.pointee.timestamp
                _ = self.delegate?.perform(self.selector, with: self)
                self.duration = 0.0
            }
            return kCVReturnSuccess
        }
    }

    func add(to runloop: RunLoop, forMode mode: RunLoop.Mode) {
        guard let displayLink = displayLink, !isPaused else {
            return
        }
        CVDisplayLinkStart(displayLink)
    }

    func invalidate() {
        guard let displayLink = displayLink, isPaused else {
            return
        }
        CVDisplayLinkStop(displayLink)
    }
}

extension CVTimeStamp {
    @inlinable @inline(__always)
    var timestamp: Double {
        Double(self.videoTime) / Double(self.videoTimeScale)
    }

    @inlinable @inline(__always) var duration: Double {
        Double(self.videoRefreshPeriod) / Double(self.videoTimeScale)
    }
}

// swiftlint:enable attributes

#else
import QuartzCore
typealias DisplayLink = CADisplayLink
#endif

protocol ChoreographerDelegate: AnyObject {
    func choreographer(_ choreographer: some Choreographer, didFrame duration: Double)
}

protocol Choreographer: Runner {
    var isPaused: Bool { get set }
    var delegate: (any ChoreographerDelegate)? { get set }

    func clear()
}

final class DisplayLinkChoreographer: NSObject, Choreographer {
    private static let duration = 0.0
    private static let preferredFramesPerSecond = 0

    var isPaused: Bool {
        get {
            displayLink?.isPaused ?? true
        }
        set {
            displayLink?.isPaused = newValue
        }
    }
    weak var delegate: (any ChoreographerDelegate)?
    var isRunning = false
    var preferredFramesPerSecond = DisplayLinkChoreographer.preferredFramesPerSecond
    private var duration: Double = DisplayLinkChoreographer.duration
    private var displayLink: DisplayLink? {
        didSet {
            oldValue?.invalidate()
            guard let displayLink = displayLink else {
                return
            }
            displayLink.isPaused = true
            displayLink.preferredFramesPerSecond = preferredFramesPerSecond
            displayLink.add(to: .main, forMode: .common)
        }
    }

    func clear() {
        duration = Self.duration
    }

    @objc
    private func update(displayLink: DisplayLink) {
        delegate?.choreographer(self, didFrame: duration)
        duration += displayLink.duration
    }
}

extension DisplayLinkChoreographer: Runner {
    func startRunning() {
        displayLink = DisplayLink(target: self, selector: #selector(self.update(displayLink:)))
        isRunning = true
    }

    func stopRunning() {
        displayLink = nil
        duration = DisplayLinkChoreographer.duration
        isRunning = false
    }
}
