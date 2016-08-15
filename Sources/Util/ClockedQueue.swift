import Foundation
import AVFoundation

// MARK: ClockedQueueDelegate
protocol ClockedQueueDelegate:class {
    func queue(buffer: Any)
}

// MARK: -
class ClockedQueue<T> {
    var bufferTime:NSTimeInterval = 0.1 // sec
    private(set) var running:Bool = false
    private(set) var duration:NSTimeInterval = 0
    weak var delegate:ClockedQueueDelegate?

    private var date:NSDate = NSDate()
    private var buffers:[T] = []
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

    func enqueue(buffer:T) {
        do {
            try mutex.lock()
            duration += getDuration(buffer)
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

    func getDuration(buffer:T) -> NSTimeInterval {
        return 0
    }

    @objc func onTimer(timer:NSTimer) {
        guard let buffer:T = buffers.first where bufferTime <= self.duration else {
            return
        }
        let duration:NSTimeInterval = getDuration(buffer)
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

// MARK: -
final class CMSampleBufferClockedQueue:ClockedQueue<CMSampleBuffer> {
    override func getDuration(buffer: CMSampleBuffer) -> NSTimeInterval {
        return buffer.duration.seconds
    }
}

// MARK: -
final class DecompressionBufferClockedQueue:ClockedQueue<DecompressionBuffer> {
    override func getDuration(buffer: DecompressionBuffer) -> NSTimeInterval {
        return buffer.duration.seconds
    }
}
