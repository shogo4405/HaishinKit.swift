import Foundation
final class RTSPRecordSequenceResponder: RTSPResponder {
    private var uri:String
    private var stream:RTSPStream
    private var method:RTSPMethod = .OPTIONS

    init(uri:String, stream:RTSPStream) {
        self.uri = uri
        self.stream = stream
    }

    func onResponse(response: RTSPResponse) {
        switch method {
        case .OPTIONS:
            method = .SETUP
            stream.connection.doMethod(.SETUP, uri, ["Transport":"RTP/AVP;unicast;client_port=8000-8001"], self)
        case .DESCRIBE:
            method = .SETUP
            stream.connection.doMethod(.SETUP, uri, [:], self)
        case .SETUP:
            method = .RECORD
            stream.connection.doMethod(.RECORD, uri, [:], self)
        case .RECORD:
            break
        default:
            break
        }
    }
}

// MARK: -
class RTSPStream: Stream {
    var sessionID:String?
    private var services:[RTPService] = []
    private var connection:RTSPConnection

    init(connection: RTSPConnection) {
        self.connection = connection
    }

    func record(uri:String) {
        connection.doMethod(.OPTIONS, uri, [:], RTSPRecordSequenceResponder(uri: uri, stream: self))
    }

    func tearDown() {
    }
}
