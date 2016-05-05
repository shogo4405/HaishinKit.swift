import lf
import Cocoa
import AVFoundation

final class LiveViewController: NSViewController {

    var popUpButton:NSPopUpButton!
    var publishButton:NSButton!

    var url:String = "rtmp://test:test@localhost/live"
    var rtmpConnection:RTMPConnection = RTMPConnection()
    var rtmpStream:RTMPStream!

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.frame = NSMakeRect(0, 0, 640, 360)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        rtmpStream = RTMPStream(rtmpConnection: rtmpConnection)
        rtmpStream.view.wantsLayer = true

        publishButton = NSButton()
        publishButton.title = "Publish"
        publishButton.action = #selector(LiveViewController.publishOrStop(_:))
        publishButton.target = self

        popUpButton = NSPopUpButton()
        popUpButton.action = #selector(LiveViewController.selectCamera(_:))
        popUpButton.target = self
        let cameras:[AnyObject]! = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo)
        for camera in cameras {
            if let camera:AVCaptureDevice = camera as? AVCaptureDevice {
                popUpButton.addItemWithTitle(camera.localizedName)
            }
        }
        if (!cameras.isEmpty) {
            rtmpStream.attachCamera(cameras[0] as? AVCaptureDevice)
        }

        view.addSubview(rtmpStream.view)
        view.addSubview(popUpButton)
        view.addSubview(publishButton)
    }

    override func viewWillLayout() {
        super.viewWillLayout()
        rtmpStream.view.frame = view.frame
        publishButton.frame = NSMakeRect(view.frame.width - 120, view.frame.height - 40, 100, 20)
        popUpButton.frame = NSMakeRect(view.frame.width - 220, 20, 200, 20)
    }

    func selectCamera(sender:AnyObject) {
        let devices:[AnyObject]! = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo)
        let title:String = popUpButton.itemTitles[popUpButton.indexOfSelectedItem]
        for device in devices {
            guard let device:AVCaptureDevice = device as? AVCaptureDevice
                where device.localizedName == title else {
                continue
            }
            rtmpStream.attachCamera(device)
        }
    }

    func publishOrStop(sender:NSButton) {
        rtmpConnection.addEventListener(Event.RTMP_STATUS, selector:#selector(LiveViewController.rtmpStatusHandler(_:)), observer: self)
        rtmpConnection.connect(url)
    }

    func rtmpStatusHandler(notification:NSNotification) {
        let e:Event = Event.from(notification)
        if let data:ASObject = e.data as? ASObject , code:String = data["code"] as? String {
            switch code {
            case RTMPConnection.Code.ConnectSuccess.rawValue:
                rtmpStream!.publish("test")
            // sharedObject!.connect(rtmpConnection)
            default:
                break
            }
        }
    }
}
