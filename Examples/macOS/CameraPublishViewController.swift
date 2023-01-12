import AVFoundation
import Cocoa
import HaishinKit
import VideoToolbox

extension NSPopUpButton {
    fileprivate func present(mediaType: AVMediaType) {
        let devices = AVCaptureDevice.devices(for: mediaType)
        devices.forEach {
            self.addItem(withTitle: $0.localizedName)
        }
    }
}

final class CameraPublishViewController: NSViewController {
    @IBOutlet private weak var lfView: MTHKView!
    @IBOutlet private weak var audioPopUpButton: NSPopUpButton!
    @IBOutlet private weak var cameraPopUpButton: NSPopUpButton!
    @IBOutlet private weak var urlField: NSTextField!
    @IBOutlet private weak var segmentedControl: NSSegmentedControl!

    private var currentStream: NetStream? {
        willSet {
            currentStream?.attachCamera(nil)
            currentStream?.attachMultiCamera(nil)
            currentStream?.attachAudio(nil)
        }
        didSet {
            currentStream?.attachCamera(DeviceUtil.device(withLocalizedName: cameraPopUpButton.titleOfSelectedItem!, mediaType: .video))
            currentStream?.attachAudio(DeviceUtil.device(withLocalizedName: audioPopUpButton.titleOfSelectedItem!, mediaType: .audio))
        }
    }
    private var rtmpConnection = RTMPConnection()
    private lazy var rtmpStream: RTMPStream = {
        let rtmpStream = RTMPStream(connection: rtmpConnection)
        rtmpStream.addObserver(self, forKeyPath: "currentFPS", options: .new, context: nil)
        return rtmpStream
    }()
    private var httpService = HLSService(
        domain: "local", type: HTTPService.type, name: "", port: HTTPService.defaultPort
    )
    private var httpStream = HTTPStream()

    override func viewDidLoad() {
        super.viewDidLoad()
        urlField.stringValue = Preference.defaultInstance.uri ?? ""
        audioPopUpButton?.present(mediaType: .audio)
        cameraPopUpButton?.present(mediaType: .video)
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        rtmpStream.attachAudio(DeviceUtil.device(withLocalizedName: audioPopUpButton.titleOfSelectedItem!, mediaType: .audio))
        rtmpStream.attachCamera(DeviceUtil.device(withLocalizedName: cameraPopUpButton.titleOfSelectedItem!, mediaType: .video))
        var devices = AVCaptureDevice.devices(for: .video)
        devices.removeFirst()
        if let device = devices.first {
            rtmpStream.attachMultiCamera(device)
        }
        lfView?.attachStream(rtmpStream)
        currentStream = rtmpStream
    }

    // swiftlint:disable block_based_kvo
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        guard let keyPath: String = keyPath, Thread.isMainThread else {
            return
        }
        switch keyPath {
        case "currentFPS":
            view.window!.title = "HaishinKit(FPS: \(rtmpStream.currentFPS): totalBytesIn: \(rtmpConnection.totalBytesIn): totalBytesOut: \(rtmpConnection.totalBytesOut))"
        default:
            break
        }
    }

    @IBAction private func publishOrStop(_ sender: NSButton) {
        // Publish
        if sender.title == "Publish" {
            sender.title = "Stop"
            // Optional. If you don't specify; the frame size will be the current H264Encoder default of 480x272
            //            rtmpStream.videoSettings = [
            //                .profileLevel: kVTProfileLevel_H264_High_AutoLevel,
            //                .width: 1920,
            //                .height: 1280,
            //            ]
            segmentedControl.isEnabled = false
            switch segmentedControl.selectedSegment {
            case 0:
                rtmpConnection.addEventListener(.rtmpStatus, selector: #selector(rtmpStatusHandler), observer: self)
                rtmpConnection.connect(urlField.stringValue)
            case 1:
                httpStream.publish("hello")
                httpService.addHTTPStream(httpStream)
                httpService.startRunning()
            default:
                break
            }
            return
        }
        // Stop
        sender.title = "Publish"
        segmentedControl.isEnabled = true
        switch segmentedControl.selectedSegment {
        case 0:
            rtmpConnection.removeEventListener(.rtmpStatus, selector: #selector(rtmpStatusHandler), observer: self)
            rtmpConnection.close()
        case 1:
            httpService.removeHTTPStream(httpStream)
            httpService.stopRunning()
            httpStream.publish(nil)
        default:
            break
        }
        return
    }

    @IBAction private func orientation(_ sender: AnyObject) {
        lfView.rotate(byDegrees: 90)
    }

    @IBAction private func mirror(_ sender: AnyObject) {
        currentStream?.videoCapture(for: 0)?.isVideoMirrored.toggle()
    }

    @IBAction private func selectAudio(_ sender: AnyObject) {
        let device = DeviceUtil.device(withLocalizedName: audioPopUpButton.titleOfSelectedItem!, mediaType: .audio)
        currentStream?.attachAudio(device)
    }

    @IBAction private func selectCamera(_ sender: AnyObject) {
        let device = DeviceUtil.device(withLocalizedName: cameraPopUpButton.titleOfSelectedItem!, mediaType: .video)
        currentStream?.attachCamera(device)
    }

    @IBAction private func modeChanged(_ sender: NSSegmentedControl) {
        switch sender.selectedSegment {
        case 0:
            currentStream = rtmpStream
            lfView.attachStream(rtmpStream)
            urlField.stringValue = Preference.defaultInstance.uri ?? ""
        case 1:
            currentStream = httpStream
            lfView.attachStream(httpStream)
            urlField.stringValue = "http://{ipAddress}:8080/hello/playlist.m3u8"
        default:
            break
        }
    }

    @objc
    private func rtmpStatusHandler(_ notification: Notification) {
        let e = Event.from(notification)
        guard
            let data: ASObject = e.data as? ASObject,
            let code: String = data["code"] as? String else {
            return
        }
        logger.info(data)
        switch code {
        case RTMPConnection.Code.connectSuccess.rawValue:
            rtmpStream.publish(Preference.defaultInstance.streamName)
        default:
            break
        }
    }
}
