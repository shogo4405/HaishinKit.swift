import AVFoundation
import AVKit
import Foundation
import HaishinKit
import UIKit

final class PlaybackViewController: UIViewController {
    @IBOutlet private weak var playbackButton: UIButton!
    private let netStreamSwitcher: NetStreamSwitcher = .init()
    private var stream: IOStream {
        return netStreamSwitcher.stream
    }
    private var pictureInPictureController: AVPictureInPictureController?

    override func viewWillAppear(_ animated: Bool) {
        logger.info("viewWillAppear")
        super.viewWillAppear(animated)
        netStreamSwitcher.uri = Preference.defaultInstance.uri ?? ""
        (view as? (any IOStreamView))?.attachStream(stream)
        if #available(iOS 15.0, *), let layer = view.layer as? AVSampleBufferDisplayLayer, pictureInPictureController == nil {
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
            netStreamSwitcher.close()
            button.setTitle("●", for: [])
        } else {
            UIApplication.shared.isIdleTimerDisabled = true
            netStreamSwitcher.open(.playback)
            button.setTitle("■", for: [])
        }
        button.isSelected.toggle()
    }

    @objc
    private func didBecomeActive(_ notification: Notification) {
        logger.info(notification)
        if pictureInPictureController?.isPictureInPictureActive == false {
            (stream as? RTMPStream)?.receiveVideo = true
        }
    }

    @objc
    private func didEnterBackground(_ notification: Notification) {
        logger.info(notification)
        if pictureInPictureController?.isPictureInPictureActive == false {
            (stream as? RTMPStream)?.receiveVideo = false
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
