import Foundation

protocol TimerDriverDelegate: class {
    func tick(_ driver:TimerDriver)
}

// MARK: -
final class LoggerTimerDriverDelegate: TimerDriverDelegate {
    func tick(_ driver:TimerDriver) {
        logger.info("-")
    }
}

// MARK: -
class TimerDriver {
    var interval:UInt64 = MachUtil.nanosToAbs(10 * MachUtil.nanosPerMsec)
    weak var delegate:TimerDriverDelegate?

    fileprivate var runloop:RunLoop?
    fileprivate var lastFired:UInt64 = 0
    fileprivate weak var timer:Timer? {
        didSet {
            if let oldValue:Timer = oldValue {
                oldValue.invalidate()
            }
            if let timer:Timer = timer {
                RunLoop.current.add(timer, forMode: .commonModes)
            }
        }
    }

    @objc func on(timer:Timer) {
        let now:UInt64 = mach_absolute_time()
        guard interval <= now - lastFired else {
            return
        }
        lastFired = now
        delegate?.tick(self)
    }
}

extension TimerDriver: CustomStringConvertible {
    // MARK: CustomStringConvertible
    var description:String {
        return Mirror(reflecting: self).description
    }
}

extension TimerDriver: Runnable {
    var running:Bool {
        return runloop != nil
    }

    // MARK: Runnable
    final func startRunning() {
        if let _:RunLoop = runloop {
            return
        }
        timer = Timer(
            timeInterval: 0.0001, target: self, selector: #selector(TimerDriver.on(timer:)), userInfo: nil, repeats: true
        )
        runloop = .current
        runloop?.run()
    }

    final func stopRunning() {
        guard let runloop:RunLoop = runloop else {
            return
        }
        timer = nil
        CFRunLoopStop(runloop.getCFRunLoop())
        self.runloop = nil
    }
}
