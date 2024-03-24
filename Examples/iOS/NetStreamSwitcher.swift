import AVFoundation
import Foundation
import HaishinKit
import SRTHaishinKit

final class NetStreamSwitcher {
    private static let maxRetryCount: Int = 5

    enum Mode {
        case rtmp
        case srt

        func makeStream(_ swithcer: NetStreamSwitcher) -> IOStream {
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
            stream = mode.makeStream(self)
        }
    }
    private var retryCount = 0
    private var connection: Any?
    private var method: Method = .ingest
    private(set) var stream: IOStream = .init() {
        didSet {
            stream.delegate = self
        }
    }

    func open(_ method: Method) {
        self.method = method
        switch mode {
        case .rtmp:
            guard let connection = connection as? RTMPConnection else {
                return
            }
            // Performing operations for FMLE compatibility purposes.
            (stream as? RTMPStream)?.fcPublishName = Preference.defaultInstance.streamName
            connection.addEventListener(.rtmpStatus, selector: #selector(rtmpStatusHandler), observer: self)
            connection.addEventListener(.ioError, selector: #selector(rtmpErrorHandler), observer: self)
            connection.connect(uri)
        case .srt:
            guard let connection = connection as? SRTConnection, let stream = stream as? SRTStream else {
                return
            }
            connection.open(URL(string: uri))
            switch method {
            case .playback:
                stream.play()
            case .ingest:
                stream.publish()
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
            guard let connection = connection as? SRTConnection, let stream = stream as? SRTStream else {
                return
            }
            stream.close()
            connection.close()
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
                (stream as? RTMPStream)?.play(Preference.defaultInstance.streamName!)
            case .ingest:
                (stream as? RTMPStream)?.publish(Preference.defaultInstance.streamName!)
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
        (connection as? RTMPConnection)?.connect(Preference.defaultInstance.uri!)
    }
}

extension NetStreamSwitcher: IOStreamDelegate {
    // MARK: NetStreamDelegate
    /// Tells the receiver to playback an audio packet incoming.
    func stream(_ stream: IOStream, didOutput audio: AVAudioBuffer, when: AVAudioTime) {
    }

    /// Tells the receiver to playback a video packet incoming.
    func stream(_ stream: IOStream, didOutput video: CMSampleBuffer) {
    }

    #if os(iOS) || os(tvOS)
    /// Tells the receiver to session was interrupted.
    @available(tvOS 17.0, *)
    func stream(_ stream: IOStream, sessionWasInterrupted session: AVCaptureSession, reason: AVCaptureSession.InterruptionReason?) {
    }

    /// Tells the receiver to session interrupted ended.
    @available(tvOS 17.0, *)
    func stream(_ stream: IOStream, sessionInterruptionEnded session: AVCaptureSession) {
    }

    #endif
    /// Tells the receiver to video codec error occured.
    func stream(_ stream: IOStream, videoErrorOccurred error: IOVideoUnitError) {
    }

    /// Tells the receiver to audio codec error occured.
    func stream(_ stream: IOStream, audioErrorOccurred error: IOAudioUnitError) {
    }

    /// Tells the receiver to the stream opened.
    func streamDidOpen(_ stream: IOStream) {
    }

    /// Tells the receiver that the ready state will change.
    func stream(_ stream: IOStream, willChangeReadyState state: IOStream.ReadyState) {
    }

    /// Tells the receiver that the ready state did change.
    func stream(_ stream: IOStream, didChangeReadyState state: IOStream.ReadyState) {
    }
}
