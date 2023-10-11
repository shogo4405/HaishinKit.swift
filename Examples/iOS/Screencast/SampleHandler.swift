import HaishinKit
import Logboard
import ReplayKit
import VideoToolbox

let logger = LBLogger.with(HaishinKitIdentifier)

@available(iOS 10.0, *)
open class SampleHandler: RPBroadcastSampleHandler {
    private lazy var rtmpConnection: RTMPConnection = {
        let conneciton = RTMPConnection()
        conneciton.addEventListener(.rtmpStatus, selector: #selector(rtmpStatusEvent), observer: self)
        conneciton.addEventListener(.ioError, selector: #selector(rtmpErrorHandler), observer: self)
        return conneciton
    }()

    private lazy var rtmpStream: RTMPStream = {
        RTMPStream(connection: rtmpConnection)
    }()

    private var isMirophoneOn = false

    deinit {
        rtmpConnection.removeEventListener(.ioError, selector: #selector(rtmpErrorHandler), observer: self)
        rtmpConnection.removeEventListener(.rtmpStatus, selector: #selector(rtmpStatusEvent), observer: self)
    }

    override open func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        /*
         let socket = SocketAppender()
         socket.connect("192.168.1.9", port: 22222)
         logger.level = .debug
         logger.appender = socket
         logger.level = .debug
         */
        LBLogger.with(HaishinKitIdentifier).level = .info
        rtmpConnection.connect(Preference.defaultInstance.uri!, arguments: nil)
    }

    override open func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case .video:
            if let description = CMSampleBufferGetFormatDescription(sampleBuffer) {
                let dimensions = CMVideoFormatDescriptionGetDimensions(description)
                rtmpStream.videoSettings.videoSize = .init(width: CGFloat(dimensions.width), height: CGFloat(dimensions.height))
                rtmpStream.videoSettings.profileLevel = kVTProfileLevel_H264_Baseline_AutoLevel as String
            }
            rtmpStream.append(sampleBuffer)
        case .audioMic:
            isMirophoneOn = true
            if CMSampleBufferDataIsReady(sampleBuffer) {
                rtmpStream.append(sampleBuffer)
            }
        case .audioApp:
            if !isMirophoneOn && CMSampleBufferDataIsReady(sampleBuffer) {
                rtmpStream.append(sampleBuffer)
            }
        @unknown default:
            break
        }
    }

    @objc
    private func rtmpErrorHandler(_ notification: Notification) {
        logger.info(notification)
        rtmpConnection.connect(Preference.defaultInstance.uri!)
    }

    @objc
    private func rtmpStatusEvent(_ status: Notification) {
        let e = Event.from(status)
        logger.info(e)
        guard
            let data: ASObject = e.data as? ASObject,
            let code: String = data["code"] as? String else {
            return
        }
        switch code {
        case RTMPConnection.Code.connectSuccess.rawValue:
            rtmpStream.publish(Preference.defaultInstance.streamName!)
        default:
            break
        }
    }
}
