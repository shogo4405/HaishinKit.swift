import Foundation

/// A type that methods for running.
public protocol Runner: AnyObject {
    /// Indicates whether the receiver is running.
    var isRunning: Bool { get }
    /// Tells the receiver to start running.
    func startRunning()
    /// Tells the receiver to stop running.
    func stopRunning()
}

/// A type that methods for running.
public protocol AsyncRunner: Actor {
    /// Indicates whether the receiver is running.
    var isRunning: Bool { get }
    /// Tells the receiver to start running.
    func startRunning() async
    /// Tells the receiver to stop running.
    func stopRunning() async
}
