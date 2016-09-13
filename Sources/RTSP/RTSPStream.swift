import Foundation

final class RTSPPlaySequenceResponder: RTSPResponder {
    fileprivate var uri:String
    fileprivate var stream:RTSPStream
    fileprivate var method:RTSPMethod = .options

    init(uri:String, stream:RTSPStream) {
        self.uri = uri
        self.stream = stream
    }

    func on(response: RTSPResponse) {
        switch method {
        case .options:
            method = .describe
            stream.connection.doMethod(.describe, uri, self, [:])
        case .describe:
            method = .setup
            stream.listen()
            stream.connection.doMethod(.setup, uri, self, ["Transport":"RTP/AVP;unicast;client_port=8000-8001"])
        case .setup:
            method = .play
            stream.connection.doMethod(.play, uri, self, [:])
        default:
            break
        }
    }
}

// MARK: -
final class RTSPRecordSequenceResponder: RTSPResponder {
    fileprivate var uri:String
    fileprivate var stream:RTSPStream
    fileprivate var method:RTSPMethod = .options

    init(uri:String, stream:RTSPStream) {
        self.uri = uri
        self.stream = stream
    }

    func on(response: RTSPResponse) {
    }
}

// MARK: -
class RTSPStream: NetStream {
    var sessionID:String?
    fileprivate var services:[RTPService] = []
    fileprivate var connection:RTSPConnection

    init(connection: RTSPConnection) {
        self.connection = connection
    }

    func play(uri:String) {
        connection.doMethod(.options, uri, RTSPPlaySequenceResponder(uri: uri, stream: self), [:])
    }

    func record(uri:String) {
        connection.doMethod(.options, uri, RTSPRecordSequenceResponder(uri: uri, stream: self), [:])
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
