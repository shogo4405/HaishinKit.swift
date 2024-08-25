import AVFoundation
import AVKit
import HaishinKit
import UIKit

final class ViewController: UIViewController {
    enum Mode {
        case publish
        case playback
    }

    @IBOutlet private weak var lfView: MTHKView!
    @IBOutlet private weak var playbackOrPublishSegment: UISegmentedControl! {
        didSet {
            guard !AVContinuityDevicePickerViewController.isSupported else {
                return
            }
            playbackOrPublishSegment.removeSegment(at: 1, animated: false)
        }
    }
    private var mode: Mode = .playback {
        didSet {
            logger.info(mode)
        }
    }
    private var mixer = MediaMixer()
    private let netStreamSwitcher: HKStreamSwitcher = .init()

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Task { @MainActor in
            var videoMixerSettings = await mixer.videoMixerSettings
            videoMixerSettings.mode = .offscreen
            await mixer.setVideoMixerSettings(videoMixerSettings)
            await netStreamSwitcher.setPreference(Preference.default)
            if let stream = await netStreamSwitcher.stream {
                await mixer.addOutput(stream)
                if let view = view as? (any HKStreamOutput) {
                    await stream.addOutput(view)
                }
            }
        }
    }

    @IBAction func segmentedControl(_ sender: UISegmentedControl) {
        switch sender.titleForSegment(at: sender.selectedSegmentIndex) {
        case "Publish":
            mode = .publish
        case "Playback":
            mode = .playback
        default:
            break
        }
    }

    @IBAction func go(_ sender: UIButton) {
        switch mode {
        case .publish:
            let picker = AVContinuityDevicePickerViewController()
            picker.delegate = self
            present(picker, animated: true)
        case .playback:
            Task {
                await netStreamSwitcher.open(.playback)
            }
        }
    }
}

extension ViewController: AVContinuityDevicePickerViewControllerDelegate {
    // MARK: AVContinuityDevicePickerViewControllerDelegate
    nonisolated func continuityDevicePicker( _ pickerViewController: AVContinuityDevicePickerViewController, didConnect device: AVContinuityDevice) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .voiceChat, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
            Task {
                try await mixer.attachAudio(AVCaptureDevice.default(for: .audio))
            }
        } catch {
            logger.error(error)
        }
        if let camera = device.videoDevices.first {
            logger.info(camera)
            Task {
                try await mixer.attachVideo(camera)
            }
        }
    }
}
