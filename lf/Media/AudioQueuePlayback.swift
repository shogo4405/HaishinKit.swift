import Foundation
import AudioToolbox
import AVFoundation

public class AudioQueuePlayback: NSObject {
    public private(set) var running:Bool = false

    private var queue:AudioQueueRef? = nil
    private let lockQueue:dispatch_queue_t = dispatch_queue_create("com.github.shogo4405.lf.AudioPlayback.lock", DISPATCH_QUEUE_SERIAL)

    private var callback:AudioQueueOutputCallback = { (
        inUserData: UnsafeMutablePointer<Void>,
        inAQ: AudioQueueRef,
        inBuffer:AudioQueueBufferRef) -> Void in
    }

    public func startRunnning() {
        dispatch_async(lockQueue) {
            guard !self.running else {
                return
            }
            self.queue = AudioQueueRef()
        }
    }

    public func stopRunnning() {
        dispatch_async(lockQueue) {
            self.running = false
            self.queue = nil
        }
    }

    private func newOutput(inFormat: UnsafePointer<AudioStreamBasicDescription>) -> OSStatus {
        var queue:AudioQueueRef = self.queue!
        let status:OSStatus = AudioQueueNewOutput(inFormat, callback, unsafeBitCast(self, UnsafeMutablePointer<Void>.self), CFRunLoopGetCurrent(), kCFRunLoopCommonModes, 0, &queue)
        return status
    }
}
