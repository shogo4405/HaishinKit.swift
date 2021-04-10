import Foundation

extension NetSocket {
    struct CycleBuffer: CustomDebugStringConvertible {
        var bytes: UnsafePointer<UInt8>? {
            data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> UnsafePointer<UInt8>? in
                bytes.baseAddress?.assumingMemoryBound(to: UInt8.self).advanced(by: top)
            }
        }
        var maxLength: Int {
            min(count, capacity - top)
        }
        var debugDescription: String {
            Mirror(reflecting: self).debugDescription
        }
        private var count: Int {
            let value = bottom - top
            return value < 0 ? value + capacity : value
        }
        private var data: Data
        private var capacity: Int = 0 {
            didSet {
                logger.info("extends a buffer size from ", oldValue, " to ", capacity)
            }
        }
        private var top: Int = 0
        private var bottom: Int = 0
        private var locked: UnsafeMutablePointer<UInt32>?
        private var lockedBottom: Int = -1

        init(capacity: Int) {
            self.capacity = capacity
            data = .init(repeating: 0, count: capacity)
        }

        mutating func append(_ data: Data, locked: UnsafeMutablePointer<UInt32>? = nil) {
            guard data.count + count < capacity else {
                extend(data)
                return
            }
            let count = data.count
            if self.locked == nil {
                self.locked = locked
            }
            let length = min(count, capacity - bottom)
            self.data.replaceSubrange(bottom..<bottom + length, with: data)
            if length < count {
                bottom = count - length
                self.data.replaceSubrange(0..<bottom, with: data.advanced(by: length))
            } else {
                bottom += count
            }
            if capacity == bottom {
                bottom = 0
            }
            if locked != nil {
                lockedBottom = bottom
            }
        }

        mutating func markAsRead(_ count: Int) {
            let length = min(count, capacity - top)
            if length < count {
                top = count - length
            } else {
                top += count
            }
            if capacity == top {
                top = 0
            }
            if let locked = locked, -1 < lockedBottom && lockedBottom <= top {
                OSAtomicAnd32Barrier(0, locked)
                lockedBottom = -1
            }
        }

        mutating func clear() {
            top = 0
            bottom = 0
            locked = nil
            lockedBottom = 0
        }

        private mutating func extend(_ data: Data) {
            if 0 < top {
                let subdata = self.data.subdata(in: 0..<bottom)
                self.data.replaceSubrange(0..<capacity - top, with: self.data.advanced(by: top))
                self.data.replaceSubrange(capacity - top..<capacity - top + subdata.count, with: subdata)
                bottom = capacity - top + subdata.count
            }
            self.data.append(.init(count: capacity))
            top = 0
            capacity = self.data.count
            append(data)
        }
    }
}
