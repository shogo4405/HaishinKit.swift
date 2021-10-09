import Foundation

#if os(macOS)
#else
import QuartzCore
typealias DisplayLink = CADisplayLink
#endif

protocol ChoreographerDelegate: AnyObject {
    func choreographer(_ choreographer: Choreographer, didFrame duration: Double)
}

protocol Choreographer: Running {
    var isPaused: Bool { get set }
    var delegate: ChoreographerDelegate? { get set }

    func clear()
}

final class DisplayLinkChoreographer: NSObject, Choreographer {
    static let defaultPreferredFramesPerSecond = 0

    var isPaused: Bool {
        get {
            displayLink?.isPaused ?? true
        }
        set {
            displayLink?.isPaused = newValue
        }
    }
    weak var delegate: ChoreographerDelegate?
    var isRunning: Atomic<Bool> = .init(false)
    private var duration: Double = 0.0
    private var displayLink: DisplayLink? {
        didSet {
            oldValue?.invalidate()
            guard let displayLink = displayLink else {
                return
            }
            displayLink.isPaused = true
            if #available(iOS 10.0, tvOS 10.0, *) {
                displayLink.preferredFramesPerSecond = Self.defaultPreferredFramesPerSecond
            } else {
                displayLink.frameInterval = 1
            }
            displayLink.add(to: .main, forMode: .common)
        }
    }

    func clear() {
        duration = 0.0
    }

    @objc
    private func update(displayLink: DisplayLink) {
        delegate?.choreographer(self, didFrame: duration)
        duration += displayLink.duration
    }
}

extension DisplayLinkChoreographer: Running {
    func startRunning() {
        displayLink = DisplayLink(target: self, selector: #selector(self.update(displayLink:)))
        isRunning.mutate { $0 = true }
    }

    func stopRunning() {
        displayLink = nil
        duration = 0.0
        isRunning.mutate { $0 = false }
    }
}
