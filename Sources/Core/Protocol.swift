protocol DataConvertible {
    var data: Data { get set }
}

// MARK: -
protocol Running: class {
    var running: Bool { get }
    func startRunning()
    func stopRunning()
}
