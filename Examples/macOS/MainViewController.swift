import HaishinKit
import Cocoa
import Foundation
import AVFoundation
import VideoToolbox

final class MainViewController: NSViewController {
    var rtmpConnection:RTMPConnection = RTMPConnection()
    var rtmpStream:RTMPStream!

    var httpService:HLSService = HLSService(
        domain: "local", type: HTTPService.type, name: "", port: HTTPService.defaultPort
    )
    var httpStream:HTTPStream = HTTPStream()

    @IBOutlet var lfView:GLLFView!
    @IBOutlet var audioPopUpButton:NSPopUpButton!
    @IBOutlet var cameraPopUpButton:NSPopUpButton!
    @IBOutlet var urlField:NSTextField!
    @IBOutlet var segmentedControl:NSSegmentedControl!

    override func viewDidLoad() {
        super.viewDidLoad()
        rtmpStream = RTMPStream(connection: rtmpConnection)
        rtmpStream.addObserver(self, forKeyPath: "currentFPS", options: .new, context: nil)

        urlField.stringValue = Preference.defaultInstance.uri ?? ""

        let audios:[Any]! = AVCaptureDevice.devices(for: AVMediaType.audio)
        for audio in audios {
            if let audio:AVCaptureDevice = audio as? AVCaptureDevice {
                audioPopUpButton?.addItem(withTitle: audio.localizedName)
            }
        }

        let cameras:[Any]! = AVCaptureDevice.devices(for: AVMediaType.video)
        for camera in cameras {
            if let camera:AVCaptureDevice = camera as? AVCaptureDevice {
                cameraPopUpButton?.addItem(withTitle: camera.localizedName)
            }
        }
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        rtmpStream.attachAudio(DeviceUtil.device(withLocalizedName: audioPopUpButton.itemTitles[audioPopUpButton.indexOfSelectedItem], mediaType: AVMediaType.audio.rawValue))
        rtmpStream.attachCamera(DeviceUtil.device(withLocalizedName: cameraPopUpButton.itemTitles[cameraPopUpButton.indexOfSelectedItem], mediaType: AVMediaType.video.rawValue))
        lfView?.attachStream(rtmpStream)
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let keyPath:String = keyPath, Thread.isMainThread else {
            return
        }
        switch keyPath {
        case "currentFPS":
            view.window!.title = "HaishinKit(FPS:\(rtmpStream.currentFPS):totalBytesIn:\(rtmpConnection.totalBytesIn):totalBytesOut:\(rtmpConnection.totalBytesOut))"
        default:
            break
        }
    }

    @IBAction func publishOrStop(_ sender:NSButton) {
        // Publish
        if (sender.title == "Publish") {
            sender.title = "Stop"
            segmentedControl.isEnabled = false
            switch segmentedControl.selectedSegment {
            case 0:
                rtmpConnection.addEventListener(Event.RTMP_STATUS, selector:#selector(MainViewController.rtmpStatusHandler(_:)), observer: self)
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
            rtmpConnection.removeEventListener(Event.RTMP_STATUS, selector:#selector(MainViewController.rtmpStatusHandler(_:)), observer: self)
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

    @IBAction func selectAudio(_ sender:AnyObject) {
        let device:AVCaptureDevice? = DeviceUtil.device(withLocalizedName:
            audioPopUpButton.itemTitles[audioPopUpButton.indexOfSelectedItem], mediaType: AVMediaType.audio.rawValue
        )
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
    
    @IBAction func selectCamera(_ sender:AnyObject) {
        let device:AVCaptureDevice? = DeviceUtil.device(withLocalizedName:
            cameraPopUpButton.itemTitles[cameraPopUpButton.indexOfSelectedItem], mediaType: AVMediaType.video.rawValue
        )
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

    @IBAction func modeChanged(_ sender:NSSegmentedControl) {
        switch sender.selectedSegment {
        case 0:
            httpStream.attachAudio(nil)
            httpStream.attachCamera(nil)
            rtmpStream.attachAudio(DeviceUtil.device(withLocalizedName: audioPopUpButton.itemTitles[audioPopUpButton.indexOfSelectedItem], mediaType: AVMediaType.audio.rawValue))
            rtmpStream.attachCamera(DeviceUtil.device(withLocalizedName: cameraPopUpButton.itemTitles[cameraPopUpButton.indexOfSelectedItem], mediaType: AVMediaType.video.rawValue))
            lfView.attachStream(rtmpStream)
            urlField.stringValue = Preference.defaultInstance.uri ?? ""
        case 1:
            rtmpStream.attachAudio(nil)
            rtmpStream.attachCamera(nil)
            httpStream.attachAudio(DeviceUtil.device(withLocalizedName: audioPopUpButton.itemTitles[audioPopUpButton.indexOfSelectedItem], mediaType: AVMediaType.audio.rawValue))
            httpStream.attachCamera(DeviceUtil.device(withLocalizedName: cameraPopUpButton.itemTitles[cameraPopUpButton.indexOfSelectedItem], mediaType: AVMediaType.video.rawValue))
            lfView.attachStream(httpStream)
            urlField.stringValue = "http://{ipAddress}:8080/hello/playlist.m3u8"
        default:
            break
        }
    }

    @objc func rtmpStatusHandler(_ notification:Notification) {
        let e:Event = Event.from(notification)
        guard
            let data:ASObject = e.data as? ASObject,
            let code:String = data["code"] as? String else {
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
