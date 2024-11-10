import Foundation

/// A structor that provides the statistics related to the RTMPStream.
public struct RTMPStreamInfo {
    /// The number of bytes received by the RTMPStream.
    public internal(set) var byteCount = 0
    /// The resource name of a stream.
    public internal(set) var resourceName: String?
    /// The number of bytes received per second by the RTMPStream.
    public internal(set) var currentBytesPerSecond = 0
    private var previousByteCount = 0

    mutating func update() {
        currentBytesPerSecond = byteCount - previousByteCount
        previousByteCount = byteCount
    }

    mutating func clear() {
        byteCount = 0
        currentBytesPerSecond = 0
        previousByteCount = 0
    }
}

extension RTMPStreamInfo: CustomDebugStringConvertible {
    // MARK: CustomDebugStringConvertible
    public var debugDescription: String {
        Mirror(reflecting: self).debugDescription
    }
}
