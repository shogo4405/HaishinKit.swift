import Foundation

/// A type that methods for running.
public protocol Running: AnyObject {
    /// Indicates whether the receiver is running.
    var isRunning: Atomic<Bool> { get }
    /// Tells the receiver to start running.
    func startRunning()
    /// Tells the receiver to stop running.
    func stopRunning()
}
