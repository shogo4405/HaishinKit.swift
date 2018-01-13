import Foundation

protocol DataConvertible {
    var data: Data { get set }
}

// MARK: -
protocol Runnable: class {
    var running: Bool { get }
    func startRunning()
    func stopRunning()
}
