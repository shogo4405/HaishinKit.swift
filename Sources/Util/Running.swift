import Foundation

public protocol Running: class {
    var isRunning: Bool { get }

    func startRunning()
    func stopRunning()
}
