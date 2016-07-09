import lf
import Cocoa
import AVFoundation

final class LiveViewController: NSViewController {
    static let defaultURL:String = "rtmp://test:test@localhost/live"

    var enabledSharedObject:Bool = false
    var rtmpConnection:RTMPConnection = RTMPConnection()
    var rtmpStream:RTMPStream!
    var sharedObject:RTMPSharedObject!

    var httpService:HTTPService = HTTPService(
        domain: "localhost", type: HTTPService.type, name: "", port: HTTPService.defaultPort
    )
    var httpStream:HTTPStream = HTTPStream()

    var urlField:NSTextField = {
        let field:NSTextField = NSTextField()
        field.stringValue = LiveViewController.defaultURL
        return field
    }()

    var publishButton:NSButton = {
        let button:NSButton = NSButton()
        button.title = "Publish"
        button.action = #selector(LiveViewController.publishOrStop(_:))
        return button
    }()

    var fpsPopUpButton:NSPopUpButton = {
        let button:NSPopUpButton = NSPopUpButton()
        button.action = #selector(LiveViewController.selectFPS(_:))
        button.addItemWithTitle("30")
        button.addItemWithTitle("60")
        button.addItemWithTitle("15")
        button.addItemWithTitle("1")
        return button
    }()

    var audioPopUpButton:NSPopUpButton = {
        let button:NSPopUpButton = NSPopUpButton()
        button.action = #selector(LiveViewController.selectAudio(_:))
        let audios:[AnyObject]! = AVCaptureDevice.devicesWithMediaType(AVMediaTypeAudio)
        for audio in audios {
            if let audio:AVCaptureDevice = audio as? AVCaptureDevice {
                button.addItemWithTitle(audio.localizedName)
            }
        }
        return button
    }()

    var cameraPopUpButton:NSPopUpButton = {
        let button:NSPopUpButton = NSPopUpButton()
        button.action = #selector(LiveViewController.selectCamera(_:))
        let cameras:[AnyObject]! = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo)
        for camera in cameras {
            if let camera:AVCaptureDevice = camera as? AVCaptureDevice {
                button.addItemWithTitle(camera.localizedName)
            }
        }
        return button
    }()

    var segmentedControl:NSSegmentedControl = {
        let segmented:NSSegmentedControl = NSSegmentedControl()
        segmented.segmentCount = 2
        segmented.action = #selector(LiveViewController.modeChanged(_:))
        segmented.setLabel("RTMP", forSegment: 0)
        segmented.setLabel("HTTP", forSegment: 1)
        segmented.selectedSegment = 0
        return segmented
    }()

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.frame = NSMakeRect(0, 0, 640, 360)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        audioPopUpButton.target = self
        cameraPopUpButton.target = self
        rtmpStream = RTMPStream(rtmpConnection: rtmpConnection)
        rtmpStream.attachAudio(
            AVMixer.deviceWithLocalizedName(audioPopUpButton.itemTitles[audioPopUpButton.indexOfSelectedItem], mediaType: AVMediaTypeAudio)
        )
        rtmpStream.attachCamera(
            AVMixer.deviceWithLocalizedName(cameraPopUpButton.itemTitles[cameraPopUpButton.indexOfSelectedItem], mediaType: AVMediaTypeVideo)
        )

        rtmpStream.addObserver(self, forKeyPath: "currentFPS", options: .New, context: nil)
        publishButton.target = self
        rtmpStream.view.wantsLayer = true
        view.addSubview(rtmpStream.view)
        httpStream.view.wantsLayer = true
        view.addSubview(httpStream.view)
        view.addSubview(fpsPopUpButton)
        view.addSubview(cameraPopUpButton)
        view.addSubview(audioPopUpButton)
        view.addSubview(publishButton)
        view.addSubview(segmentedControl)
        view.addSubview(urlField)
    }

    override func viewWillLayout() {
        super.viewWillLayout()
        rtmpStream.view.frame = view.frame
        httpStream.view.frame = view.frame
        urlField.frame = NSMakeRect(20, 20, 300, 20)
        segmentedControl.frame = NSMakeRect(20, view.frame.height - 40, 200, 20)
        fpsPopUpButton.frame = NSMakeRect(20, view.frame.height - 70, 120, 20)
        publishButton.frame = NSMakeRect(view.frame.width - 120, view.frame.height - 40, 100, 20)
        cameraPopUpButton.frame = NSMakeRect(view.frame.width - 220, 50, 200, 20)
        audioPopUpButton.frame = NSMakeRect(view.frame.width - 220, 20, 200, 20)
    }

    func publishOrStop(sender:NSButton) {
        // Publish
        if (sender.title == "Publish") {
            sender.title = "Stop"
            segmentedControl.enabled = false
            switch segmentedControl.selectedSegment {
            case 0:
                rtmpConnection.addEventListener(Event.RTMP_STATUS, selector:#selector(LiveViewController.rtmpStatusHandler(_:)), observer: self)
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
        segmentedControl.enabled = true
        switch segmentedControl.selectedSegment {
        case 0:
            rtmpConnection.removeEventListener(Event.RTMP_STATUS, selector:#selector(LiveViewController.rtmpStatusHandler(_:)), observer: self)
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

    func modeChanged(sender:NSSegmentedControl) {
        switch sender.selectedSegment {
        case 0:
            httpStream.attachAudio(nil)
            httpStream.attachCamera(nil)
            rtmpStream.attachAudio(AVMixer.deviceWithLocalizedName(audioPopUpButton.itemTitles[audioPopUpButton.indexOfSelectedItem], mediaType: AVMediaTypeAudio))
            rtmpStream.attachCamera(AVMixer.deviceWithLocalizedName(cameraPopUpButton.itemTitles[cameraPopUpButton.indexOfSelectedItem], mediaType: AVMediaTypeVideo))
            urlField.stringValue = LiveViewController.defaultURL
        case 1:
            rtmpStream.attachAudio(nil)
            rtmpStream.attachCamera(nil)
            httpStream.attachAudio(AVMixer.deviceWithLocalizedName(audioPopUpButton.itemTitles[audioPopUpButton.indexOfSelectedItem], mediaType: AVMediaTypeAudio))
            httpStream.attachCamera(AVMixer.deviceWithLocalizedName(cameraPopUpButton.itemTitles[cameraPopUpButton.indexOfSelectedItem], mediaType: AVMediaTypeVideo))
            urlField.stringValue = "http://{ipAddress}:8080/hello/playlist.m3u8"
        default:
            break
        }
    }

    func selectAudio(sender:AnyObject) {
        let device:AVCaptureDevice? = AVMixer.deviceWithLocalizedName(
            audioPopUpButton.itemTitles[audioPopUpButton.indexOfSelectedItem], mediaType: AVMediaTypeAudio
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

    func selectCamera(sender:AnyObject) {
        let device:AVCaptureDevice? = AVMixer.deviceWithLocalizedName(
            cameraPopUpButton.itemTitles[cameraPopUpButton.indexOfSelectedItem], mediaType: AVMediaTypeVideo
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

    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        guard let keyPath:String = keyPath where NSThread.isMainThread() else {
            return
        }
        switch keyPath {
        case "currentFPS":
            view.window!.title = "lf - lIVE fRAMEWORK(FPS:\(rtmpStream.currentFPS):totalBytesIn:\(rtmpConnection.totalBytesIn):totalBytesOut:\(rtmpConnection.totalBytesOut)"
        default:
            break
        }
    }

    func selectFPS(sender:AnyObject) {
        let value:String = fpsPopUpButton.itemTitles[fpsPopUpButton.indexOfSelectedItem]
        rtmpStream.captureSettings["fps"] = value
        httpStream.captureSettings["fps"] = value
    }

    func rtmpStatusHandler(notification:NSNotification) {
        let e:Event = Event.from(notification)
        if let data:ASObject = e.data as? ASObject , code:String = data["code"] as? String {
            switch code {
            case RTMPConnection.Code.ConnectSuccess.rawValue:
                rtmpStream!.publish("live")
                if (enabledSharedObject) {
                    sharedObject = RTMPSharedObject.getRemote("test", remotePath: urlField.stringValue, persistence: false)
                    sharedObject.connect(rtmpConnection)
                    sharedObject.setProperty("Hello", "World!!")
                }
            default:
                break
            }
        }
    }
}

extension LiveViewController: NSWindowDelegate {
    func windowWillClose(notification: NSNotification) {
        NSApp.terminate(self)
    }
}
