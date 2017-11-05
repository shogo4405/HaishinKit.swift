import Foundation
import AVFoundation

protocol ClockedQueueDelegate:class {
    func queue(_ buffer: CMSampleBuffer)
}

// MARK: -
final class ClockedQueue {
    var bufferTime:TimeInterval = 0.1 // sec
    private(set) var duration:TimeInterval = 0
    weak var delegate:ClockedQueueDelegate?

    private var isReady:Bool = false
    private var buffers:[CMSampleBuffer] = []
    private lazy var driver:TimerDriver = {
        var driver:TimerDriver = TimerDriver()
        driver.setDelegate(self, withQueue: self.lockQueue)
        return driver
    }()
    private let lockQueue:DispatchQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.ClockedQueue.lock")

    func enqueue(_ buffer:CMSampleBuffer) {
        lockQueue.async {
            self.duration += buffer.duration.seconds
            self.buffers.append(buffer)
            if (!self.isReady) {
                self.isReady = self.duration <= self.bufferTime
            }
        }
    }
}

extension ClockedQueue: Runnable {
    // MARK: Runnable
    var running:Bool {
        return driver.running
    }

    final func startRunning() {
        guard !running else {
            return
        }
        isReady = false
        driver.startRunning()
    }

    final func stopRunning() {
        guard running else {
            return
        }
        isReady = false
        duration = 0
        buffers.removeAll()
        driver.stopRunning()
    }
}

extension ClockedQueue: TimerDriverDelegate {
    // MARK: TimerDriverDelegate
    func tick(_ driver:TimerDriver) {
        guard let first:CMSampleBuffer = buffers.first, isReady else {
            return
        }
        delegate?.queue(first)
        duration -= first.duration.seconds
        driver.interval = MachUtil.nanosToAbs(UInt64(first.duration.seconds * 1000 * 1000 * 1000))
        buffers.removeFirst()
    }
}

extension ClockedQueue: CustomStringConvertible {
    // MARK: CustomStringConvertible
    var description:String {
        return Mirror(reflecting: self).description
    }
}
