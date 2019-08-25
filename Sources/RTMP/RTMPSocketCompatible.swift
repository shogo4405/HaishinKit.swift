import Foundation

enum RTMPSocketReadyState: UInt8 {
    case uninitialized = 0
    case versionSent = 1
    case ackSent = 2
    case handshakeDone = 3
    case closing = 4
    case closed = 5
}

protocol RTMPSocketCompatible: class {
    var timeout: Int { get set }
    var delegate: RTMPSocketDelegate? { get set }
    var connected: Bool { get }
    var timestamp: TimeInterval { get }
    var readyState: RTMPSocketReadyState { get set }
    var chunkSizeC: Int { get set }
    var chunkSizeS: Int { get set }
    var inputBuffer: Data { get set }
    var totalBytesIn: Int64 { get }
    var totalBytesOut: Int64 { get }
    var queueBytesOut: Int64 { get }
    var securityLevel: StreamSocketSecurityLevel { get set }
    var qualityOfService: DispatchQoS { get set }

    @discardableResult
    func doOutput(chunk: RTMPChunk, locked: UnsafeMutablePointer<UInt32>?) -> Int
    func close(isDisconnected: Bool)
    func connect(withName: String, port: Int)
    func deinitConnection(isDisconnected: Bool)
    func setProperty(_ value: Any?, forKey: String)
    func didTimeout()
}

extension RTMPSocketCompatible {
    func setProperty(_ value: Any?, forKey: String) {
    }

    func didTimeout() {
        deinitConnection(isDisconnected: false)
        delegate?.dispatch(Event.IO_ERROR, bubbles: false, data: nil)
        logger.warn("connection timedout")
    }
}

// MARK: -
protocol RTMPSocketDelegate: IEventDispatcher {
    func listen(_ data: Data)
    func didSetReadyState(_ readyState: RTMPSocketReadyState)
    func didSetTotalBytesIn(_ totalBytesIn: Int64)
}
