import Foundation

final public class AtomicInteger64 {
    private let lock = DispatchSemaphore(value: 1)
    private var _value: Int64

    public init(value initialValue: Int64 = 0) {
        _value = initialValue
    }

    public var value: Int64 {
        get {
            lock.wait()
            defer { lock.signal() }
            return _value
        }
        set {
            lock.wait()
            defer { lock.signal() }
            _value = newValue
        }
    }
}
