import Foundation

public protocol TimerDriverDelegate: class {
    func tick(_ driver:TimerDriver)
}

// MARK: -
public class TimerDriver: NSObject {
    public var interval:UInt64 = MachUtil.nanosToAbs(10 * MachUtil.nanosPerMsec)

    var queue:DispatchQueue?
    weak var delegate:TimerDriverDelegate?

    private var runloop:RunLoop?
    private var nextFire:UInt64 = 0
    private weak var timer:Timer? {
        didSet {
            if let oldValue:Timer = oldValue {
                oldValue.invalidate()
            }
            if let timer:Timer = timer {
                RunLoop.current.add(timer, forMode: .commonModes)
            }
        }
    }

    public override var description:String {
        return Mirror(reflecting: self).description
    }

    public func setDelegate(_ delegate:TimerDriverDelegate, withQueue:DispatchQueue? = nil) {
        self.delegate = delegate
        self.queue = withQueue
    }

    @objc func on(timer:Timer) {
        guard nextFire <= mach_absolute_time() else {
            return
        }
        if let queue:DispatchQueue = queue {
            queue.sync {
                self.delegate?.tick(self)
            }
        } else {
            delegate?.tick(self)
        }
        nextFire += interval
    }
}

extension TimerDriver: Runnable {
    // MARK: Runnable
    public var running:Bool {
        return runloop != nil
    }

    final public func startRunning() {
        DispatchQueue.global(qos: .userInteractive).async {
            if let _:RunLoop = self.runloop {
                return
            }
            self.timer = Timer(
                timeInterval: 0.0001, target: self, selector: #selector(TimerDriver.on(timer:)), userInfo: nil, repeats: true
            )
            self.nextFire = mach_absolute_time() + self.interval
            self.delegate?.tick(self)
            self.runloop = .current
            self.runloop?.run()
        }
    }

    final public func stopRunning() {
        guard let runloop:RunLoop = runloop else {
            return
        }
        timer = nil
        CFRunLoopStop(runloop.getCFRunLoop())
        self.runloop = nil
    }
}
