import lf
import UIKit
import AVFoundation

struct Preference {
    static let defaultInstance:Preference = Preference()

    var uri:String? = "rtmp://test:test@192.168.179.4/live"
    var streamName:String? = "live"
}

final class LiveViewController: UIViewController {
    var rtmpConnection:RTMPConnection = RTMPConnection()
    var rtmpStream:RTMPStream!
    var sharedObject:RTMPSharedObject!
    var currentEffect:VisualEffect? = nil
    var httpService:HTTPService!
    var httpStream:HTTPStream!

    let touchView: UIView! = UIView()
    
    let lfView:GLLFView! = GLLFView(frame: CGRect.zero)

    var currentFPSLabel:UILabel = {
        let label:UILabel = UILabel()
        label.textColor = UIColor.white
        return label
    }()

    var publishButton:UIButton = {
        let button:UIButton = UIButton()
        button.backgroundColor = UIColor.blue
        button.setTitle("●", for: UIControlState())
        button.layer.masksToBounds = true
        return button
    }()

    var videoBitrateLabel:UILabel = {
        let label:UILabel = UILabel()
        label.textColor = UIColor.white
        return label
    }()

    var videoBitrateSlider:UISlider = {
        let slider:UISlider = UISlider()
        slider.minimumValue = 32
        slider.maximumValue = 1024
        return slider
    }()

    var audioBitrateLabel:UILabel = {
        let label:UILabel = UILabel()
        label.textColor = UIColor.white
        return label
    }()

    var zoomSlider:UISlider = {
        let slider:UISlider = UISlider()
        slider.minimumValue = 0.0
        slider.maximumValue = 5.0
        return slider
    }()

    var audioBitrateSlider:UISlider = {
        let slider:UISlider = UISlider()
        slider.minimumValue = 16
        slider.maximumValue = 120
        return slider
    }()

    var fpsControl:UISegmentedControl = {
        let segment:UISegmentedControl = UISegmentedControl(items: ["15.0", "30.0", "60.0"])
        segment.tintColor = UIColor.white
        return segment
    }()

    var effectSegmentControl:UISegmentedControl = {
        let segment:UISegmentedControl = UISegmentedControl(items: ["None", "Monochrome", "Pronama"])
        segment.tintColor = UIColor.white
        return segment
    }()

    var currentPosition:AVCaptureDevicePosition = AVCaptureDevicePosition.back

    override func viewDidLoad() {
        super.viewDidLoad()

        currentFPSLabel.text = "FPS"

        zoomSlider.addTarget(self, action: #selector(LiveViewController.onSliderValueChanged(_:)), for: .valueChanged)
        videoBitrateSlider.addTarget(self, action: #selector(LiveViewController.onSliderValueChanged(_:)), for: .valueChanged)
        audioBitrateSlider.addTarget(self, action: #selector(LiveViewController.onSliderValueChanged(_:)), for: .valueChanged)
        fpsControl.addTarget(self, action: #selector(LiveViewController.onFPSValueChanged(_:)), for: .valueChanged)
        effectSegmentControl.addTarget(self, action: #selector(LiveViewController.onEffectValueChanged(_:)), for: .valueChanged)

        /*
        navigationItem.leftBarButtonItem =
            UIBarButtonItem(title: "Preference", style: .Plain, target: self, action: "showPreference:")
        sharedObject = RTMPSharedObject.getRemote("test", remotePath: Preference.defaultInstance.uri!, persistence: false)
        */

        /*
        httpStream = HTTPStream()
        //httpStream.attachScreen(ScreenCaptureSession())
        httpStream.syncOrientation = true
        httpStream.attachCamera(AVMixer.deviceWithPosition(.Back))
        httpStream.publish("hello")

        httpService = HTTPService(domain: "", type: "_http._tcp", name: "lf", port: 8080)
        httpService.startRunning()
        httpService.addHTTPStream(httpStream)
        */

        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "Torch", style: .plain, target: self, action: #selector(LiveViewController.toggleTorch(_:))),
            UIBarButtonItem(title: "Camera", style: .plain, target: self, action: #selector(LiveViewController.rotateCamera(_:)))
        ]

        rtmpStream = RTMPStream(rtmpConnection: rtmpConnection)
        rtmpStream.syncOrientation = true
        
        rtmpStream.attachAudio(AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeAudio))
        rtmpStream.attachCamera(DeviceUtil.deviceWithPosition(.back))
        rtmpStream.addObserver(self, forKeyPath: "currentFPS", options: NSKeyValueObservingOptions.new, context: nil)
        //rtmpStream.attachScreen(ScreenCaptureSession())

        rtmpStream.captureSettings = [
            "sessionPreset": AVCaptureSessionPreset1280x720,
            "continuousAutofocus": true,
            "continuousExposure": true,
        ]

        rtmpStream.videoSettings = [
            "width": 1280,
            "height": 720,
        ]

        publishButton.addTarget(self, action: #selector(LiveViewController.onClickPublish(_:)), for: .touchUpInside)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(LiveViewController.tapScreen(_:)))
        touchView.addGestureRecognizer(tapGesture)
        touchView.frame = view.frame
        touchView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        videoBitrateSlider.value = Float(RTMPStream.defaultVideoBitrate) / 1024
        audioBitrateSlider.value = Float(RTMPStream.defaultAudioBitrate) / 1024

        lfView.attachStream(rtmpStream)

        view.addSubview(lfView)
        view.addSubview(touchView)
        view.addSubview(videoBitrateLabel)
        view.addSubview(videoBitrateSlider)
        view.addSubview(audioBitrateLabel)
        view.addSubview(audioBitrateSlider)
        view.addSubview(zoomSlider)
        view.addSubview(fpsControl)
        view.addSubview(currentFPSLabel)
        view.addSubview(effectSegmentControl)
        view.addSubview(publishButton)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        let navigationHeight:CGFloat = 66
        lfView.frame = view.bounds
        fpsControl.frame = CGRect(x: view.bounds.width - 200 - 10 , y: navigationHeight + 40, width: 200, height: 30)
        effectSegmentControl.frame = CGRect(x: view.bounds.width - 200 - 10 , y: navigationHeight, width: 200, height: 30)
        publishButton.frame = CGRect(x: view.bounds.width - 44 - 20, y: view.bounds.height - 44 - 20, width: 44, height: 44)
        currentFPSLabel.frame = CGRect(x: 10, y: 10, width: 40, height: 40)
        zoomSlider.frame = CGRect(x: 20, y: view.frame.height - 44 * 3 - 22, width: view.frame.width - 44 - 60, height: 44)
        videoBitrateLabel.text = "video \(Int(videoBitrateSlider.value))/kbps"
        videoBitrateLabel.frame = CGRect(x: view.frame.width - 150 - 60, y: view.frame.height - 44 * 2 - 22, width: 150, height: 44)
        videoBitrateSlider.frame = CGRect(x: 20, y: view.frame.height - 44 * 2, width: view.frame.width - 44 - 60, height: 44)
        audioBitrateLabel.text = "audio \(Int(audioBitrateSlider.value))/kbps"
        audioBitrateLabel.frame = CGRect(x: view.frame.width - 150 - 60, y: view.frame.height - 44 - 22, width: 150, height: 44)
        audioBitrateSlider.frame = CGRect(x: 20, y: view.frame.height - 44, width: view.frame.width - 44 - 60, height: 44)
    }

    func rotateCamera(_ sender:UIBarButtonItem) {
        let position:AVCaptureDevicePosition = currentPosition == .back ? .front : .back
        rtmpStream.attachCamera(DeviceUtil.deviceWithPosition(position))
        currentPosition = position
    }

    func toggleTorch(_ sender:UIBarButtonItem) {
        rtmpStream.torch = !rtmpStream.torch
    }

    func showPreference(_ sender:UIBarButtonItem) {
        let preference:PreferenceController = PreferenceController()
        preference.view.backgroundColor = UIColor(colorLiteralRed: 1.0, green: 1.0, blue: 1.0, alpha: 0.25)
        preference.view.frame = view.frame
        preference.modalPresentationStyle = .overCurrentContext
        preference.modalTransitionStyle = .crossDissolve
        present(preference, animated: true, completion: nil)
    }

    func onSliderValueChanged(_ slider:UISlider) {
        if (slider == audioBitrateSlider) {
            audioBitrateLabel.text = "audio \(Int(slider.value))/kbps"
            rtmpStream.audioSettings["bitrate"] = slider.value * 1024
        }
        if (slider == videoBitrateSlider) {
            videoBitrateLabel.text = "video \(Int(slider.value))/kbsp"
            rtmpStream.videoSettings["bitrate"] = slider.value * 1024
        }
        if (slider == zoomSlider) {
            rtmpStream.rampToVideoZoomFactor(CGFloat(slider.value), withRate: 5.0)
        }
    }

    func onClickPublish(_ sender:UIButton) {
        if (sender.isSelected) {
            UIApplication.shared.isIdleTimerDisabled = false
            rtmpConnection.close()
            rtmpConnection.removeEventListener(Event.RTMP_STATUS, selector:#selector(LiveViewController.rtmpStatusHandler(_:)), observer: self)
            sender.setTitle("●", for: UIControlState())
        } else {
            UIApplication.shared.isIdleTimerDisabled = true
            rtmpConnection.addEventListener(Event.RTMP_STATUS, selector:#selector(LiveViewController.rtmpStatusHandler(_:)), observer: self)
            rtmpConnection.connect(Preference.defaultInstance.uri!)
            sender.setTitle("■", for: UIControlState())
        }
        sender.isSelected = !sender.isSelected
    }

    func rtmpStatusHandler(_ notification:Notification) {
        let e:Event = Event.from(notification)
        if let data:ASObject = e.data as? ASObject , let code:String = data["code"] as? String {
            switch code {
            case RTMPConnection.Code.ConnectSuccess.rawValue:
                rtmpStream!.publish(Preference.defaultInstance.streamName!)
                // sharedObject!.connect(rtmpConnection)
            default:
                break
            }
        }
    }

    func tapScreen(_ gesture: UIGestureRecognizer) {
        if let gestureView = gesture.view , gesture.state == .ended {
            let touchPoint: CGPoint = gesture.location(in: gestureView)
            let pointOfInterest: CGPoint = CGPoint(x: touchPoint.x/gestureView.bounds.size.width,
                y: touchPoint.y/gestureView.bounds.size.height)
            print("pointOfInterest: \(pointOfInterest)")
            rtmpStream.setPointOfInterest(pointOfInterest, exposure: pointOfInterest)
        }
    }

    func onFPSValueChanged(_ segment:UISegmentedControl) {
        switch segment.selectedSegmentIndex {
        case 0:
            rtmpStream.captureSettings["fps"] = 15.0
        case 1:
            rtmpStream.captureSettings["fps"] = 30.0
        case 2:
            rtmpStream.captureSettings["fps"] = 60.0
        default:
            break
        }
    }

    func onEffectValueChanged(_ segment:UISegmentedControl) {
        if let currentEffect:VisualEffect = currentEffect {
            rtmpStream.unregisterEffect(video: currentEffect)
        }
        switch segment.selectedSegmentIndex {
        case 1:
            currentEffect = MonochromeEffect()
            rtmpStream.registerEffect(video: currentEffect!)
        case 2:
            currentEffect = PronamaEffect()
            rtmpStream.registerEffect(video: currentEffect!)
        default:
            break
        }
    }

    /*
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [String : Any]?, context: UnsafeMutableRawPointer?) {
        if (Thread.isMainThread) {
            currentFPSLabel.text = "\(rtmpStream.currentFPS)"
        }
    }
    */
}
