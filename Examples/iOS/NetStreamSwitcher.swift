import AVFoundation
import Foundation
import HaishinKit
import SRTHaishinKit

final class NetStreamSwitcher {
    private static let maxRetryCount: Int = 5

    enum Mode {
        case rtmp
        case srt

        func makeStream(_ swithcer: NetStreamSwitcher) async -> any IOStreamConvertible {
            switch self {
            case .rtmp:
                let connection = RTMPConnection()
                swithcer.connection = connection
                return RTMPStream(connection: connection)
            case .srt:
                let connection = SRTConnection()
                swithcer.connection = connection
                return await SRTStream(connection: connection)
            }
        }
    }

    enum Method {
        case ingest
        case playback
    }

    var uri = "" {
        didSet {
            if uri.contains("srt://") {
                mode = .srt
                return
            }
            mode = .rtmp
        }
    }
    private(set) var mode: Mode = .rtmp {
        didSet {
            Task {
                stream = await mode.makeStream(self)
            }
        }
    }
    private var retryCount = 0
    private var connection: Any?
    private var method: Method = .ingest
    private(set) var stream: (any IOStreamConvertible)? {
        didSet {
            // stream?.delegate = self
        }
    }

    func open(_ method: Method) {
        self.method = method
        switch mode {
        case .rtmp:
            guard let connection = connection as? RTMPConnection else {
                return
            }
            switch method {
            case .ingest:
                // Performing operations for FMLE compatibility purposes.
                (stream as? RTMPStream)?.fcPublishName = Preference.default.streamName
            case .playback:
                break
            }
            connection.addEventListener(.rtmpStatus, selector: #selector(rtmpStatusHandler), observer: self)
            connection.addEventListener(.ioError, selector: #selector(rtmpErrorHandler), observer: self)
            connection.connect(uri)
        case .srt:
            guard let connection = connection as? SRTConnection, let stream = stream as? SRTStream else {
                return
            }
            Task {
                do {
                    try await connection.open(URL(string: uri))
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
    }

    func close() {
        switch mode {
        case .rtmp:
            guard let connection = connection as? RTMPConnection else {
                return
            }
            connection.close()
            connection.removeEventListener(.rtmpStatus, selector: #selector(rtmpStatusHandler), observer: self)
            connection.removeEventListener(.ioError, selector: #selector(rtmpErrorHandler), observer: self)
        case .srt:
            guard let connection = connection as? SRTConnection else {
                return
            }
            Task {
                await connection.close()
            }
        }
    }

    @objc
    private func rtmpStatusHandler(_ notification: Notification) {
        let e = Event.from(notification)
        guard let data: ASObject = e.data as? ASObject, let code: String = data["code"] as? String else {
            return
        }
        logger.info(code)
        switch code {
        case RTMPConnection.Code.connectSuccess.rawValue:
            retryCount = 0
            switch method {
            case .playback:
                (stream as? RTMPStream)?.play(Preference.default.streamName!)
            case .ingest:
                (stream as? RTMPStream)?.publish(Preference.default.streamName!)
            }
        case RTMPConnection.Code.connectFailed.rawValue, RTMPConnection.Code.connectClosed.rawValue:
            guard retryCount <= NetStreamSwitcher.maxRetryCount else {
                return
            }
            Thread.sleep(forTimeInterval: pow(2.0, Double(retryCount)))
            (connection as? RTMPConnection)?.connect(uri)
            retryCount += 1
        default:
            break
        }
    }

    @objc
    private func rtmpErrorHandler(_ notification: Notification) {
        logger.error(notification)
        (connection as? RTMPConnection)?.connect(Preference.default.uri!)
    }
}
