import AVFoundation
import Foundation
import HaishinKit
import SRTHaishinKit

final actor HKStreamSwitcher {
    static let maxRetryCount: Int = 5

    enum Mode {
        case rtmp
        case srt
    }

    enum Method {
        case ingest
        case playback
    }

    private var preference: Preference?
    private(set) var mode: Mode = .rtmp
    private var connection: Any?
    private var method: Method = .ingest
    private(set) var stream: (any HKStream)?

    func setPreference(_ preference: Preference) async {
        self.preference = preference
        if preference.uri?.contains("srt://") == true {
            let connection = SRTConnection()
            self.connection = connection
            stream = SRTStream(connection: connection)
            mode = .srt
        } else {
            let connection = RTMPConnection()
            self.connection = connection
            stream = RTMPStream(connection: connection)
            mode = .rtmp
        }
    }

    func open(_ method: Method) async {
        guard let preference else {
            return
        }
        self.method = method
        switch mode {
        case .rtmp:
            guard
                let connection = connection as? RTMPConnection,
                let stream = stream as? RTMPStream else {
                return
            }
            do {
                let response = try await connection.connect(preference.uri ?? "")
                logger.info(response)
                switch method {
                case .ingest:
                    let response = try await stream.publish(Preference.default.streamName)
                    logger.info(response)
                case .playback:
                    let response = try await stream.play(Preference.default.streamName)
                    logger.info(response)
                }
            } catch RTMPConnection.Error.requestFailed(let response) {
                logger.warn(response)
            } catch RTMPStream.Error.requestFailed(let response) {
                logger.warn(response)
            } catch {
                logger.warn(error)
            }
        case .srt:
            guard let connection = connection as? SRTConnection, let stream = stream as? SRTStream else {
                return
            }
            do {
                try await connection.open(URL(string: preference.uri ?? ""))
                switch method {
                case .playback:
                    await stream.play()
                case .ingest:
                    await stream.publish()
                }
            } catch {
                logger.warn(error)
            }
        }
    }

    func close() async {
        switch mode {
        case .rtmp:
            guard let connection = connection as? RTMPConnection else {
                return
            }
            try? await connection.close()
            logger.info("conneciton.close")
        case .srt:
            guard let connection = connection as? SRTConnection else {
                return
            }
            try? await connection.close()
            logger.info("conneciton.close")
        }
    }
}
