import Foundation
import AVFoundation

protocol ClockedQueueDelegate:class {
    func queue(_ buffer: CMSampleBuffer)
}

// MARK: -
class ClockedQueue {
    var bufferTime:TimeInterval = 0.1 // sec
    fileprivate(set) var running:Bool = false
    fileprivate(set) var duration:TimeInterval = 0
    weak var delegate:ClockedQueueDelegate?

    fileprivate var date:Date = Date()
    fileprivate var buffers:[CMSampleBuffer] = []
    fileprivate let mutex:Mutex = Mutex()
    fileprivate let lockQueue:DispatchQueue = DispatchQueue(
        label: "com.github.shogo4405.lf.ClockedQueue.lock", attributes: []
    )
    fileprivate var timer:Timer? {
        didSet {
            if let oldValue:Timer = oldValue {
                oldValue.invalidate()
            }
            if let timer:Timer = timer {
                RunLoop.main.add(timer, forMode: RunLoopMode.commonModes)
            }
        }
    }

    func enqueue(_ buffer:CMSampleBuffer) {
        do {
            try mutex.lock()
            duration += buffer.duration.seconds
            buffers.append(buffer)
            mutex.unlock()
        } catch {
            
        }
        if (timer == nil) {
            timer = Timer(
                timeInterval: 0.001, target: self, selector: #selector(ClockedQueue.on(timer:)), userInfo: nil, repeats: true
            )
        }
    }

    @objc func on(timer:Timer) {
        guard let buffer:CMSampleBuffer = buffers.first , bufferTime <= self.duration else {
            return
        }
        let duration:TimeInterval = buffer.duration.seconds
        guard duration <= abs(date.timeIntervalSinceNow) else {
            return
        }
        date = Date()
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

extension ClockedQueue: CustomStringConvertible {
    // MARK: CustomStringConvertible
    var description:String {
        return Mirror(reflecting: self).description
    }
}
