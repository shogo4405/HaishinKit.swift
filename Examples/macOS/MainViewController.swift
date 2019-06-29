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

final class MainViewController: NSViewController {
    var rtmpConnection = RTMPConnection()
    var rtmpStream: RTMPStream!

    var httpService = HLSService(
        domain: "local", type: HTTPService.type, name: "", port: HTTPService.defaultPort
    )
    var httpStream = HTTPStream()

    @IBOutlet private weak var lfView: MTHKView!
    @IBOutlet private weak var audioPopUpButton: NSPopUpButton!
    @IBOutlet private weak var cameraPopUpButton: NSPopUpButton!
    @IBOutlet private weak var urlField: NSTextField!
    @IBOutlet private weak var segmentedControl: NSSegmentedControl!

    override func viewDidLoad() {
        super.viewDidLoad()
        rtmpStream = RTMPStream(connection: rtmpConnection)
        rtmpStream.addObserver(self, forKeyPath: "currentFPS", options: .new, context: nil)

        urlField.stringValue = Preference.defaultInstance.uri ?? ""

        audioPopUpButton?.present(mediaType: .audio)
        cameraPopUpButton?.present(mediaType: .video)
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        rtmpStream.attachAudio(DeviceUtil.device(withLocalizedName: audioPopUpButton.titleOfSelectedItem!, mediaType: .audio))
        rtmpStream.attachCamera(DeviceUtil.device(withLocalizedName: cameraPopUpButton.titleOfSelectedItem!, mediaType: .video))
        lfView?.attachStream(rtmpStream)
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
    }

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

    @IBAction func publishOrStop(_ sender: NSButton) {
        // Publish
        if sender.title == "Publish" {
            sender.title = "Stop"
            segmentedControl.isEnabled = false
            switch segmentedControl.selectedSegment {
            case 0:
                rtmpConnection.addEventListener(Event.RTMP_STATUS, selector: #selector(rtmpStatusHandler), observer: self)
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
            rtmpConnection.removeEventListener(Event.RTMP_STATUS, selector: #selector(rtmpStatusHandler), observer: self)
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

    @IBAction func selectAudio(_ sender: AnyObject) {
        let device: AVCaptureDevice? = DeviceUtil.device(withLocalizedName: audioPopUpButton.titleOfSelectedItem!, mediaType: .audio)
        switch segmentedControl.selectedSegment {
        case 0:
            rtmpStream.attachAudio(device)
            httpStream.attachAudio(nil)
        case 1:
            rtmpStream.attachAudio(nil)
            httpStream.attachAudio(device)
        default:
            break
        }
    }

    @IBAction func selectCamera(_ sender: AnyObject) {
        let device: AVCaptureDevice? = DeviceUtil.device(withLocalizedName: cameraPopUpButton.titleOfSelectedItem!, mediaType: .video)
        switch segmentedControl.selectedSegment {
        case 0:
            rtmpStream.attachCamera(device)
            httpStream.attachCamera(nil)
        case 1:
            rtmpStream.attachCamera(nil)
            httpStream.attachCamera(device)
        default:
            break
        }
    }

    @IBAction func modeChanged(_ sender: NSSegmentedControl) {
        switch sender.selectedSegment {
        case 0:
            httpStream.attachAudio(nil)
            httpStream.attachCamera(nil)
            rtmpStream.attachAudio(DeviceUtil.device(withLocalizedName: audioPopUpButton.titleOfSelectedItem!, mediaType: .audio))
            rtmpStream.attachCamera(DeviceUtil.device(withLocalizedName: cameraPopUpButton.titleOfSelectedItem!, mediaType: .video))
            lfView.attachStream(rtmpStream)
            urlField.stringValue = Preference.defaultInstance.uri ?? ""
        case 1:
            rtmpStream.attachAudio(nil)
            rtmpStream.attachCamera(nil)
            httpStream.attachAudio(DeviceUtil.device(withLocalizedName: audioPopUpButton.titleOfSelectedItem!, mediaType: .audio))
            httpStream.attachCamera(DeviceUtil.device(withLocalizedName: cameraPopUpButton.titleOfSelectedItem!, mediaType: .video))
            lfView.attachStream(httpStream)
            urlField.stringValue = "http://{ipAddress}:8080/hello/playlist.m3u8"
        default:
            break
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
            rtmpStream!.publish(Preference.defaultInstance.streamName)
        default:
            break
        }
    }
}
