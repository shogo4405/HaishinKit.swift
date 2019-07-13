import CoreVideo
import Foundation

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
