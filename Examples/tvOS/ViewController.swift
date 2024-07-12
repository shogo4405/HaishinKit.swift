import AVFoundation
import AVKit
import HaishinKit
import UIKit

enum Mode {
    case publish
    case playback
}

final class ViewController: UIViewController {
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
    private var connection = RTMPConnection()
    private var stream: RTMPStream!

    override func viewDidLoad() {
        super.viewDidLoad()
        stream = RTMPStream(connection: connection)
        connection.addEventListener(.rtmpStatus, selector: #selector(rtmpStatusHandler), observer: self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        lfView?.attachStream(stream)
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
            connection.connect(Preference.default.uri!)
        }
    }

    @objc
    func rtmpStatusHandler(_ notification: Notification) {
        let e = Event.from(notification)

        guard
            let data: ASObject = e.data as? ASObject,
            let code: String = data["code"] as? String else {
            return
        }

        switch code {
        case RTMPConnection.Code.connectSuccess.rawValue:
            switch mode {
            case .publish:
                stream.publish(Preference.default.streamName)
            case .playback:
                stream.play(Preference.default.streamName)
            }
        default:
            break
        }
    }
}

extension ViewController: AVContinuityDevicePickerViewControllerDelegate {
    // MARK: AVContinuityDevicePickerViewControllerDelegate
    func continuityDevicePicker( _ pickerViewController: AVContinuityDevicePickerViewController, didConnect device: AVContinuityDevice) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .voiceChat, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
            stream.attachAudio(AVCaptureDevice.default(for: .audio))
        } catch {
            logger.error(error)
        }
        if let camera = device.videoDevices.first {
            logger.info(camera)
            stream.attachCamera(camera)
        }
        connection.connect(Preference.default.uri!)
    }
}
