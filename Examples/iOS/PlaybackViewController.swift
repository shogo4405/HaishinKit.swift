import AVFoundation
import AVKit
import Foundation
import HaishinKit
import UIKit

final class PlaybackViewController: UIViewController {
    private static let maxRetryCount: Int = 5

    @IBOutlet private weak var playbackButton: UIButton!
    private var rtmpConnection = RTMPConnection()
    private var rtmpStream: RTMPStream!
    private var retryCount: Int = 0
    private var pictureInPictureController: AVPictureInPictureController?

    override func viewDidLoad() {
        super.viewDidLoad()
        rtmpStream = RTMPStream(connection: rtmpConnection)
    }

    override func viewWillAppear(_ animated: Bool) {
        logger.info("viewWillAppear")
        super.viewWillAppear(animated)
        (view as? (any NetStreamDrawable))?.attachStream(rtmpStream)
        if #available(iOS 15.0, *), let layer = view.layer as? AVSampleBufferDisplayLayer {
            pictureInPictureController = AVPictureInPictureController(contentSource: .init(sampleBufferDisplayLayer: layer, playbackDelegate: self))
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        logger.info("viewWillDisappear")
        super.viewWillDisappear(animated)
    }

    @IBAction func didEnterPixtureInPicture(_ button: UIButton) {
        pictureInPictureController?.startPictureInPicture()
    }

    @IBAction func didPlaybackButtonTap(_ button: UIButton) {
        if button.isSelected {
            UIApplication.shared.isIdleTimerDisabled = false
            rtmpConnection.close()
            rtmpConnection.removeEventListener(.rtmpStatus, selector: #selector(rtmpStatusHandler), observer: self)
            rtmpConnection.removeEventListener(.ioError, selector: #selector(rtmpErrorHandler), observer: self)
            button.setTitle("●", for: [])
        } else {
            UIApplication.shared.isIdleTimerDisabled = true
            rtmpConnection.addEventListener(.rtmpStatus, selector: #selector(rtmpStatusHandler), observer: self)
            rtmpConnection.addEventListener(.ioError, selector: #selector(rtmpErrorHandler), observer: self)
            rtmpConnection.connect(Preference.defaultInstance.uri!)
            button.setTitle("■", for: [])
        }
        button.isSelected.toggle()
    }

    @objc
    private func rtmpStatusHandler(_ notification: Notification) {
        let e = Event.from(notification)
        guard let data = e.data as? ASObject, let code = data["code"] as? String else {
            return
        }
        logger.info(code)
        switch code {
        case RTMPConnection.Code.connectSuccess.rawValue:
            retryCount = 0
            rtmpStream.play(Preference.defaultInstance.streamName!)
        case RTMPConnection.Code.connectFailed.rawValue, RTMPConnection.Code.connectClosed.rawValue:
            guard retryCount <= PlaybackViewController.maxRetryCount else {
                return
            }
            Thread.sleep(forTimeInterval: pow(2.0, Double(retryCount)))
            rtmpConnection.connect(Preference.defaultInstance.uri!)
            retryCount += 1
        default:
            break
        }
    }

    @objc
    private func rtmpErrorHandler(_ notification: Notification) {
        logger.error(notification)
        rtmpConnection.connect(Preference.defaultInstance.uri!)
    }

    @objc
    private func didEnterBackground(_ notification: Notification) {
        logger.info(notification)
        if pictureInPictureController?.isPictureInPictureActive == false {
            rtmpStream.receiveVideo = false
        }
    }

    @objc
    private func didBecomeActive(_ notification: Notification) {
        logger.info(notification)
        if pictureInPictureController?.isPictureInPictureActive == false {
            rtmpStream.receiveVideo = true
        }
    }
}

extension PlaybackViewController: AVPictureInPictureSampleBufferPlaybackDelegate {
    // MARK: AVPictureInPictureControllerDelegate
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {
    }

    func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
        return CMTimeRange(start: .zero, duration: .positiveInfinity)
    }

    func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
        return false
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}
