public protocol RTMPStreamDelegate: class {
    func didPublishInsufficientBW(_ stream: RTMPStream, withConnection: RTMPConnection)
    func didPublishSufficientBW(_ stream: RTMPStream, withConnection: RTMPConnection)
    func clear()
}
