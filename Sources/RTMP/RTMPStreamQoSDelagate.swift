import Foundation

public protocol RTMPStreamQoSDelagate: class {
    func didPublishInsufficientBW(_ stream:RTMPStream, withConnection:RTMPConnection)
    func clear()
}
