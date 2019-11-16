import Foundation

struct CircularBuffer<Element> {
    var first: Element? {
        return buffer[top]
    }

    var count: Int {
        let value = bottom - top
        return value < 0 ? value + buffer.count : value
    }

    var isEmpty: Bool {
        let value = bottom - top
        return (value < 0 ? value + buffer.count : value) == 0
    }

    private var buffer: [Element?]

    private var top: Int = 0
    private var mask: Int = 0
    private var bottom: Int = 0

    init(_ capacity: Int) {
        buffer = .init(repeating: nil, count: capacity)
        mask = capacity - 1
    }

    mutating func append(_ newElement: Element) {
        if buffer.count - 1 <= count {
            extend()
        }
        defer {
            bottom += 1
            bottom &= mask
        }
        buffer[bottom] = newElement
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

    private mutating func extend() {
        top = 0
        bottom = count
        buffer.append(contentsOf: [Element?](repeating: nil, count: buffer.count))
        mask = buffer.count - 1
    }
}

extension CircularBuffer: CustomStringConvertible {
    // MARK: CustomStringConvertible
    var description: String {
        return buffer.description
    }
}
