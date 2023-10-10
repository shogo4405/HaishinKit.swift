import Foundation
import HaishinKit
import SRTHaishinKit

final class NetStreamSwitcher {
    private static let maxRetryCount: Int = 5

    enum Mode {
        case rtmp
        case srt

        func makeStream(_ swithcer: NetStreamSwitcher) -> NetStream {
            switch self {
            case .rtmp:
                let connection = RTMPConnection()
                swithcer.connection = connection
                return RTMPStream(connection: connection)
            case .srt:
                let connection = SRTConnection()
                swithcer.connection = connection
                return SRTStream(connection: connection)
            }
        }
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
            stream = mode.makeStream(self)
        }
    }
    private var retryCount = 0
    private var connection: Any?
    private(set) var stream: NetStream = .init()

    func open() {
        switch mode {
        case .rtmp:
            guard let connection = connection as? RTMPConnection else {
                return
            }
            connection.addEventListener(.rtmpStatus, selector: #selector(rtmpStatusHandler), observer: self)
            connection.addEventListener(.ioError, selector: #selector(rtmpErrorHandler), observer: self)
            connection.connect(uri)
        case .srt:
            guard let connection = connection as? SRTConnection, let stream = stream as? SRTStream else {
                return
            }
            connection.open(URL(string: uri))
            stream.publish("")
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
            (stream as? SRTStream)?.close()
            (connection as? SRTConnection)?.close()
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
            (stream as? RTMPStream)?.publish(Preference.defaultInstance.streamName!)
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
        (connection as? RTMPConnection)?.connect(Preference.defaultInstance.uri!)
    }
}
