import Foundation

public protocol Running: AnyObject {
    var isRunning: Atomic<Bool> { get }

    func startRunning()
    func stopRunning()
}
