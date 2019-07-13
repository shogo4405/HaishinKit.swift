import Foundation

public protocol Running: class {
    var isRunning: Atomic<Bool> { get }

    func startRunning()
    func stopRunning()
}
