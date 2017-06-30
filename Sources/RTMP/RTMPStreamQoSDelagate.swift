import Foundation

public protocol RTMPStreamQoSDelegate: class {
    func didPublishInsufficientBW(_ stream:RTMPStream, withConnection:RTMPConnection)
    func clear()
}
