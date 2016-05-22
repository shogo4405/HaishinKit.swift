import Foundation

// MARK: BytesConvertible
protocol BytesConvertible {
    var bytes:[UInt8] { get set }
}

// MARK: Runnable
protocol Runnable: class {
    var running:Bool { get }
    func startRunning()
    func stopRunning()
}

// MARK: Iterator
protocol Iterator {
    associatedtype T
    func hasNext() -> Bool
    func next() -> T?
}

