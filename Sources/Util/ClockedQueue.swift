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

    private var buffers:[T] = []
    private let lockQueue:dispatch_queue_t = dispatch_queue_create(
        "com.github.shogo4405.lf.ClockedQueue.lock", DISPATCH_QUEUE_SERIAL
    )

    func enqueue(buffer:T) -> Self {
        dispatch_async(lockQueue) {
            self.duration += self.getDuration(buffer)
            self.buffers.append(buffer)
            if (!self.running) {
                self.dequeue()
            }
        }
        return self
    }

    func getDuration(buffer:T) -> NSTimeInterval {
        return 0
    }

    private func dequeue() {
        guard bufferTime <= self.duration && !buffers.isEmpty else {
            return
        }
        let buffer:T = buffers.removeFirst()
        delegate?.queue(buffer)
        if (buffers.isEmpty) {
            running = false
            return
        }
        running = true
        let duration:NSTimeInterval = getDuration(buffers[0])
        let when:dispatch_time_t = dispatch_time(
            DISPATCH_TIME_NOW,
            Int64(duration * Double(NSEC_PER_SEC))
        )
        dispatch_after(when, lockQueue, dequeue)
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

//MARK: -
final class DecompressionBufferClockedQueue:ClockedQueue<DecompressionBuffer> {
    override func getDuration(buffer: DecompressionBuffer) -> NSTimeInterval {
        return buffer.duration.seconds
    }
}
