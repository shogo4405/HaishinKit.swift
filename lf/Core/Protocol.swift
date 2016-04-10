import Foundation

protocol BytesConvertible {
    var bytes:[UInt8] { get set }
}

protocol Runnable: class {
    func startRunning()
    func stopRunning()
}
