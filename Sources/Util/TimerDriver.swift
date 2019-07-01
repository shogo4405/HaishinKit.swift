import Foundation

public protocol TimerDriverDelegate: class {
    func tick(_ driver: TimerDriver)
}

// MARK: -
public class TimerDriver: NSObject {
    public var interval: UInt64 = MachUtil.nanosToAbs(10 * MachUtil.nanosPerMsec)

    var queue: DispatchQueue?
    weak var delegate: TimerDriverDelegate?

    private var runloop: RunLoop?
    private var nextFire: UInt64 = 0
    private var timer: Timer? {
        didSet {
            oldValue?.invalidate()
            timer.map {
                RunLoop.current.add($0, forMode: RunLoop.Mode.common)
            }
        }
    }

    override public var description: String {
        return Mirror(reflecting: self).description
    }

    public func setDelegate(_ delegate: TimerDriverDelegate, withQueue: DispatchQueue? = nil) {
        self.delegate = delegate
        self.queue = withQueue
    }

    @objc
    func on(timer: Timer) {
        guard nextFire <= mach_absolute_time() else {
            return
        }
        if let queue: DispatchQueue = queue {
            queue.sync {
                self.delegate?.tick(self)
            }
        } else {
            delegate?.tick(self)
        }
        nextFire += interval
    }
}

extension TimerDriver: Running {
    // MARK: Running
    public var isRunning: Bool {
        return runloop != nil
    }

    public func startRunning() {
        DispatchQueue.global(qos: .userInteractive).async {
            guard self.runloop == nil else {
                return
            }
            self.timer = Timer(
                timeInterval: 0.0001, target: self, selector: #selector(self.on), userInfo: nil, repeats: true
            )
            self.nextFire = mach_absolute_time() + self.interval
            self.delegate?.tick(self)
            self.runloop = .current
            self.runloop?.run()
        }
    }

    public func stopRunning() {
        guard let runloop: RunLoop = runloop else {
            return
        }
        timer = nil
        CFRunLoopStop(runloop.getCFRunLoop())
        self.runloop = nil
    }
}
