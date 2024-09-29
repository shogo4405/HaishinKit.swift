import Foundation

/// The interface is the foundation of the RTMPConneciton.
public protocol NetworkConnection: Actor {
    /// The instance connected to server(true) or not(false).
    var connected: Bool { get }

    /// Closes the connection from the server.
    func close() async throws
}
