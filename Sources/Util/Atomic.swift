import Foundation

/// Atomic<T> class
/// @see https://www.objc.io/blog/2018/12/18/atomic-variables/
public final class Atomic<A> {
    private let queue = DispatchQueue(label: "com.haishinkit.HaishinKit.Atomic")
    private var _value: A

    /// Getter for the value.
    public var value: A {
        return queue.sync { self._value }
    }

    public init(_ value: A) {
        self._value = value
    }

    /// Setter for the value.
    public func mutate(_ transform: (inout A) -> Void) {
        queue.sync {
            transform(&self._value)
        }
    }
}
