public protocol LFLogger {
    func verbose(_ message: CustomStringConvertible)
    func debug(_ message: CustomStringConvertible)
    func info(_ message: CustomStringConvertible)
    func warning(_ message: CustomStringConvertible)
    func error(_ message: CustomStringConvertible)
    func severe(_ message: CustomStringConvertible)
}
