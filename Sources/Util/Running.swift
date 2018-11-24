import Foundation

public protocol Running: class {
    var running: Bool { get }

    func startRunning()
    func stopRunning()
}
