import Foundation

public protocol RTMPStreamQoSStrategy: class {
    func didPublishInsufficientBW(streamCounts:Int, queueBytesOut:[Int64], withStream: RTMPStream)
    func clear()
}

public class NoneRTMPStreamQoSStrategy: RTMPStreamQoSStrategy {
    public func didPublishInsufficientBW(streamCounts:Int, queueBytesOut:[Int64], withStream: RTMPStream) {
    }
    public func clear() {
    }
}
