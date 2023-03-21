import Foundation

/// The InstanceHolder class provides a shared instance memory management.
public class InstanceHolder<T: Equatable> {
    private let factory: () -> T
    private var instance: T?
    private var retainCount: Int = 0
    private let queue = DispatchQueue(label: "com.haishinkit.HaishinKit.InstanceHolder.queue")

    /// Creates a new InstanceHolder.
    public init(factory: @escaping () -> T) {
        self.factory = factory
    }

    /// Retains an instance object if needed.
    public func retain() -> T? {
        queue.sync {
            if self.instance == nil {
                self.instance = factory()
            }
            self.retainCount += 1
            return self.instance
        }
    }

    /// Releases an instance object if needed.
    public func release(_ instance: T?) {
        queue.sync {
            guard 0 < self.retainCount, self.instance == instance else {
                return
            }
            self.retainCount -= 1
            if self.retainCount == 0 {
                self.instance = nil
            }
        }
    }
}
