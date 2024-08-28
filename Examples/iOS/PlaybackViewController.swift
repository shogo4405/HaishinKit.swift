import AVFoundation
import AVKit
import Foundation
import HaishinKit
import UIKit

final class PlaybackViewController: UIViewController {
    @IBOutlet private weak var playbackButton: UIButton!
    private let netStreamSwitcher: HKStreamSwitcher = .init()
    private let audioPlayer = AudioPlayer(audioEngine: AVAudioEngine())
    private var pictureInPictureController: AVPictureInPictureController?

    override func viewWillAppear(_ animated: Bool) {
        logger.info("viewWillAppear")
        super.viewWillAppear(animated)
        if #available(iOS 15.0, *), let layer = view.layer as? AVSampleBufferDisplayLayer, pictureInPictureController == nil {
            pictureInPictureController = AVPictureInPictureController(contentSource: .init(sampleBufferDisplayLayer: layer, playbackDelegate: self))
        }
        Task {
            await netStreamSwitcher.setPreference(Preference.default)
            if let stream = await netStreamSwitcher.stream {
                if let view = view as? (any HKStreamOutput) {
                    await stream.addOutput(view)
                }
            }
            await netStreamSwitcher.stream?.attachAudioPlayer(audioPlayer)
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
        Task {
            if button.isSelected {
                UIApplication.shared.isIdleTimerDisabled = false
                await netStreamSwitcher.close()
                button.setTitle("●", for: [])
            } else {
                UIApplication.shared.isIdleTimerDisabled = true
                await netStreamSwitcher.open(.playback)
                button.setTitle("■", for: [])
            }
            button.isSelected.toggle()
        }
    }

    @objc
    private func didBecomeActive(_ notification: Notification) {
        logger.info(notification)
        if pictureInPictureController?.isPictureInPictureActive == false {
            Task {
                if let stream = await netStreamSwitcher.stream as? RTMPStream {
                    _ = try? await stream.receiveVideo(true)
                }
            }
        }
    }

    @objc
    private func didEnterBackground(_ notification: Notification) {
        logger.info(notification)
        if pictureInPictureController?.isPictureInPictureActive == false {
            Task {
                if let stream = await netStreamSwitcher.stream as? RTMPStream {
                    _ = try? await stream.receiveVideo(false)
                }
            }
        }
    }
}

extension PlaybackViewController: AVPictureInPictureSampleBufferPlaybackDelegate {
    // MARK: AVPictureInPictureControllerDelegate
    nonisolated func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {
    }

    nonisolated func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
        return CMTimeRange(start: .zero, duration: .positiveInfinity)
    }

    nonisolated func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
        return false
    }

    nonisolated func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {
    }

    nonisolated func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}
