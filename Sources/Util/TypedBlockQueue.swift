import CoreMedia
import Foundation

final class TypedBlockQueue<T: AnyObject> {
    private let queue: CMBufferQueue

    @inlinable @inline(__always) var head: T? {
        guard let head = queue.head else {
            return nil
        }
        return (head as! T)
    }

    @inlinable @inline(__always) var isEmpty: Bool {
        queue.isEmpty
    }

    @inlinable @inline(__always) var duration: CMTime {
        queue.duration
    }

    init(_ queue: CMBufferQueue) {
        self.queue = queue
    }

    @inlinable
    @inline(__always)
    func enqueue(_ buffer: T) throws {
        try queue.enqueue(buffer)
    }

    @inlinable
    @inline(__always)
    func dequeue() -> T? {
        guard let value = queue.dequeue() else {
            return nil
        }
        return (value as! T)
    }

    @inlinable
    @inline(__always)
    func reset() throws {
        try queue.reset()
    }
}
