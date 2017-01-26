import Foundation

public protocol RTMPStreamQoSStrategy: class {
    func didPublishInsufficientBW(_ stream:RTMPStream, withConnection:RTMPConnection)
    func clear()
}

public class NoneRTMPStreamQoSStrategy: RTMPStreamQoSStrategy {
    public func didPublishInsufficientBW(_ stream:RTMPStream, withConnection:RTMPConnection) {
    }
    public func clear() {
    }
}
