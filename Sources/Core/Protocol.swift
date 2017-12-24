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

// MARK: -
protocol Iterator {
    associatedtype Element
    func hasNext() -> Bool
    func next() -> Element?
}
