import Foundation

final class RTSPPlaySequenceResponder: RTSPResponder {
    private var uri:String
    private var stream:RTSPStream
    private var method:RTSPMethod = .options

    init(uri:String, stream:RTSPStream) {
        self.uri = uri
        self.stream = stream
    }

    func onResponse(response: RTSPResponse) {
        switch method {
        case .options:
            method = .describe
            stream.connection.doMethod(.describe, uri, [:], self)
        case .describe:
            method = .setup
            stream.listen()
            stream.connection.doMethod(.setup, uri, ["Transport":"RTP/AVP;unicast;client_port=8000-8001"], self)
        case .setup:
            method = .play
            stream.connection.doMethod(.play, uri, [:], self)
        default:
            break
        }
    }
}

// MARK: -
final class RTSPRecordSequenceResponder: RTSPResponder {
    private var uri:String
    private var stream:RTSPStream
    private var method:RTSPMethod = .options

    init(uri:String, stream:RTSPStream) {
        self.uri = uri
        self.stream = stream
    }

    func onResponse(response: RTSPResponse) {
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

    func play(uri:String) {
        connection.doMethod(.options, uri, [:], RTSPPlaySequenceResponder(uri: uri, stream: self))
    }

    func record(uri:String) {
        connection.doMethod(.options, uri, [:], RTSPRecordSequenceResponder(uri: uri, stream: self))
    }

    func tearDown() {
    }

    func listen() {
        for i in 0..<2 {
            let service:RTPService = RTPService(domain: "", type: "_rtp._udp", name: "", port: RTSPConnection.defaultRTPPort + i)
            service.startRunning()
            services.append(service)
        }
    }
}
