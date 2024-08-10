import Foundation

/// The metadata  associated with the response to an RTMP protocol request.
public struct RTMPResponse: Sendable {
    /// The RTMP response status.
    public let status: RTMPStatus?
    /// The RTMP response arguments.
    public let arguments: [(any Sendable)?]

    init(status: RTMPStatus?, arguments: [(any Sendable)?] = []) {
        self.status = status
        self.arguments = arguments
    }

    init(_ message: RTMPCommandMessage) {
        arguments = message.arguments
        status = arguments.isEmpty ? nil : .init(arguments.first as? AMFObject)
    }
}
