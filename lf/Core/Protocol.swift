import Foundation

protocol BytesConvertible {
    var bytes:[UInt8] { get set }
}

protocol Runnable: class {
    var running:Bool { get }
    func startRunning()
    func stopRunning()
}
