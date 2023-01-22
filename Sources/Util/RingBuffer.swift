import Foundation

struct RingBuffer<Element> {
    var first: Element? {
        buffer[top]
    }

    var count: Int {
        if top == bottom {
            return first == nil ? 0 : buffer.count
        }
        let value = bottom - top
        return value < 0 ? value + buffer.count : value
    }

    // swiftlint:disable empty_count
    var isEmpty: Bool {
        count == 0
    }

    var isFull: Bool {
        return count == (mask + 1)
    }

    private var top: Int = 0
    private var mask: Int = 0
    private var bottom: Int = 0
    private var buffer: [Element?]
    private let extensible: Bool

    init(_ capacity: Int, extensible: Bool = true) {
        buffer = .init(repeating: nil, count: capacity)
        mask = capacity - 1
        self.extensible = extensible
    }

    mutating func append(_ newElement: Element) -> Bool {
        guard !isFull else {
            return extend(newElement)
        }
        defer {
            bottom += 1
            bottom &= mask
        }
        buffer[bottom] = newElement
        return true
    }

    @discardableResult
    mutating func removeFirst() -> Element? {
        defer {
            buffer[top] = nil
            top += 1
            top &= mask
        }
        return buffer[top]
    }

    mutating func removeAll() {
        for i in 0..<buffer.count {
            buffer[i] = nil
        }
        top = 0
        bottom = 0
    }

    private mutating func extend(_ newElement: Element) -> Bool {
        guard extensible else {
            return false
        }
        let tail = buffer[0..<top]
        let head = buffer[top...]
        buffer.replaceSubrange(top..., with: tail)
        buffer.replaceSubrange(0..<top, with: head)
        bottom = count
        top = 0
        buffer.append(contentsOf: [Element?](repeating: nil, count: buffer.count))
        mask = buffer.count - 1
        return append(newElement)
    }
}

extension RingBuffer: CustomStringConvertible {
    // MARK: CustomStringConvertible
    var description: String {
        buffer.description
    }
}
