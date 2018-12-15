import Foundation

final public class AtomicBool {
    private let lock = DispatchSemaphore(value: 1)
    private var _value: Bool

    public init(value initialValue: Bool = false) {
        _value = initialValue
    }

    public var value: Bool {
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
