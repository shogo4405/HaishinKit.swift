import Foundation
import AVFoundation

// MARK: ClockedQueueDelegate
protocol ClockedQueueDelegate:class {
    func queue(buffer: CMSampleBuffer)
}

// MARK: -
class ClockedQueue {
    var bufferTime:NSTimeInterval = 0.1 // sec
    private(set) var running:Bool = false
    private(set) var duration:NSTimeInterval = 0
    weak var delegate:ClockedQueueDelegate?

    private var date:NSDate = NSDate()
    private var buffers:[CMSampleBuffer] = []
    private let mutex:Mutex = Mutex()
    private let lockQueue:dispatch_queue_t = dispatch_queue_create(
        "com.github.shogo4405.lf.ClockedQueue.lock", DISPATCH_QUEUE_SERIAL
    )
    private var timer:NSTimer? {
        didSet {
            if let oldValue:NSTimer = oldValue {
                oldValue.invalidate()
            }
            if let timer:NSTimer = timer {
                NSRunLoop.mainRunLoop().addTimer(timer, forMode: NSRunLoopCommonModes)
            }
        }
    }

    func enqueue(buffer:CMSampleBuffer) {
        do {
            try mutex.lock()
            duration += buffer.duration.seconds
            buffers.append(buffer)
            mutex.unlock()
        } catch {
            
        }
        if (timer == nil) {
            timer = NSTimer(
                timeInterval: 0.001, target: self, selector: #selector(ClockedQueue.onTimer(_:)), userInfo: nil, repeats: true
            )
        }
    }

    @objc func onTimer(timer:NSTimer) {
        guard let buffer:CMSampleBuffer = buffers.first where bufferTime <= self.duration else {
            return
        }
        let duration:NSTimeInterval = buffer.duration.seconds
        guard duration <= abs(date.timeIntervalSinceNow) else {
            return
        }
        date = NSDate()
        delegate?.queue(buffer)
        do {
            try mutex.lock()
            self.duration -= duration
            buffers.removeFirst()
            mutex.unlock()
        } catch {
            
        }
    }
}

// MARK: CustomStringConvertible
extension ClockedQueue: CustomStringConvertible {
    var description:String {
        return Mirror(reflecting: self).description
    }
}
