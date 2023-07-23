#if os(macOS)

import CoreVideo
import Foundation

// swiftlint:disable attributes

final class DisplayLink: NSObject {
    var isPaused = false {
        didSet {
            guard let displayLink = displayLink, oldValue != isPaused else {
                return
            }
            if isPaused {
                status = CVDisplayLinkStop(displayLink)
            } else {
                status = CVDisplayLinkStart(displayLink)
            }
        }
    }
    var frameInterval = 0
    var preferredFramesPerSecond = 1
    private(set) var duration = 0.0
    private(set) var timestamp: CFTimeInterval = 0
    private var status: CVReturn = 0
    private var displayLink: CVDisplayLink?
    private var selector: Selector?
    private weak var delegate: NSObject?

    deinit {
        selector = nil
    }

    init(target: NSObject, selector sel: Selector) {
        super.init()
        status = CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        guard let displayLink = displayLink else {
            return
        }
        self.delegate = target
        self.selector = sel
        CVDisplayLinkSetOutputHandler(displayLink) { [unowned self] _, inNow, _, _, _ -> CVReturn in
            self.timestamp = inNow.pointee.timestamp
            self.duration = inNow.pointee.duration
            _ = self.delegate?.perform(self.selector, with: self)
            return kCVReturnSuccess
        }
    }

    func add(to runloop: RunLoop, forMode mode: RunLoop.Mode) {
        guard let displayLink = displayLink, !isPaused else {
            return
        }
        status = CVDisplayLinkStart(displayLink)
    }

    func invalidate() {
        guard let displayLink = displayLink, isPaused else {
            return
        }
        status = CVDisplayLinkStop(displayLink)
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

#endif
