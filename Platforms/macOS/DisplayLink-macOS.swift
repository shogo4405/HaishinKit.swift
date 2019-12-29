#if os(macOS)

import CoreVideo
import Foundation

final class DisplayLink: NSObject {
    var isPaused = false {
        didSet {
            guard let displayLink = displayLink else {
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

    private(set) var timestamp: CFTimeInterval = 0
    private var status: CVReturn = 0
    private var displayLink: CVDisplayLink?
    private var selector: Selector?
    private weak var delegate: NSObject?

    private var callback: CVDisplayLinkOutputCallback = { (displayLink: CVDisplayLink, inNow: UnsafePointer<CVTimeStamp>, inOutputTime: UnsafePointer<CVTimeStamp>, flagsIn: CVOptionFlags, flgasOut: UnsafeMutablePointer<CVOptionFlags>, displayLinkContext: UnsafeMutableRawPointer?) -> CVReturn in
        guard let displayLinkContext = displayLinkContext else {
            return 0
        }
        let displayLink: DisplayLink = Unmanaged<DisplayLink>.fromOpaque(displayLinkContext).takeUnretainedValue()
        displayLink.timestamp = Double(inNow.pointee.videoTime) / Double(inNow.pointee.videoTimeScale)
        _ = displayLink.delegate?.perform(displayLink.selector, with: displayLink)
        return 0
    }

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
        CVDisplayLinkSetOutputCallback(displayLink, callback, Unmanaged.passUnretained(self).toOpaque())
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

#endif
