import UIKit
import AVFoundation

@testable import lf

struct Preference {
    static let defaultInstance:Preference = Preference()

    var uri:String? = "rtmp://test:test@192.168.179.3/live"
    var streamName:String? = "live"
}

final class LiveViewController: UIViewController {
    var rtmpConnection:RTMPConnection = RTMPConnection()
    var rtmpStream:RTMPStream!
    var sharedObject:RTMPSharedObject!
    var currentEffect:VisualEffect? = nil
    var httpService:HTTPService!

    let touchView: UIView! = UIView()

    var publishButton:UIButton = {
        let button:UIButton = UIButton()
        button.backgroundColor = UIColor.blueColor()
        button.setTitle("●", forState: .Normal)
        button.layer.masksToBounds = true
        return button
    }()

    var videoBitrateLabel:UILabel = {
        let label:UILabel = UILabel()
        label.textColor = UIColor.whiteColor()
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
        label.textColor = UIColor.whiteColor()
        return label
    }()

    var audioBitrateSlider:UISlider = {
        let slider:UISlider = UISlider()
        slider.minimumValue = 16
        slider.maximumValue = 120
        return slider
    }()

    var effectSegmentControl:UISegmentedControl = {
        let segment:UISegmentedControl = UISegmentedControl(items: ["None", "Monochrome", "Pronama"])
        segment.tintColor = UIColor.whiteColor()
        return segment
    }()

    var currentPosition:AVCaptureDevicePosition = AVCaptureDevicePosition.Back

    override func viewDidLoad() {
        super.viewDidLoad()

        videoBitrateSlider.addTarget(self, action: #selector(LiveViewController.onSliderValueChanged(_:)), forControlEvents: .ValueChanged)
        audioBitrateSlider.addTarget(self, action: #selector(LiveViewController.onSliderValueChanged(_:)), forControlEvents: .ValueChanged)
        effectSegmentControl.addTarget(self, action: #selector(LiveViewController.onEffectValueChanged(_:)), forControlEvents: .ValueChanged)

        /*
        navigationItem.leftBarButtonItem =
            UIBarButtonItem(title: "Preference", style: .Plain, target: self, action: "showPreference:")
        sharedObject = RTMPSharedObject.getRemote("test", remotePath: Preference.defaultInstance.uri!, persistence: false)
        */

        httpService = HTTPService(domain: "", type: "_http._tcp", name: "lf", port: 8080)
        httpService.startRunning()

        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "Torch", style: .Plain, target: self, action: #selector(LiveViewController.toggleTorch(_:))),
            UIBarButtonItem(title: "Camera", style: .Plain, target: self, action: #selector(LiveViewController.rotateCamera(_:)))
        ]

        rtmpStream = RTMPStream(rtmpConnection: rtmpConnection)
        rtmpStream.syncOrientation = true
        rtmpStream.attachAudio(AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeAudio))
        rtmpStream.attachCamera(AVMixer.deviceWithPosition(.Back))
        // rtmpStream.attachScreen(ScreenCaptureSession())

        rtmpStream.captureSettings = [
            "continuousAutofocus": true,
            "continuousExposure": true,
        ]
        
        publishButton.addTarget(self, action: #selector(LiveViewController.onClickPublish(_:)), forControlEvents: .TouchUpInside)

        view.addSubview(rtmpStream.view)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(LiveViewController.tapScreen(_:)))
        touchView.addGestureRecognizer(tapGesture)
        touchView.frame = view.frame
        touchView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]

        videoBitrateSlider.value = Float(RTMPStream.defaultVideoBitrate) / 1024
        audioBitrateSlider.value = Float(RTMPStream.defaultAudioBitrate) / 1024

        view.addSubview(touchView)
        view.addSubview(videoBitrateLabel)
        view.addSubview(videoBitrateSlider)
        view.addSubview(audioBitrateLabel)
        view.addSubview(audioBitrateSlider)
        view.addSubview(effectSegmentControl)
        view.addSubview(publishButton)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        let navigationHeight:CGFloat = 66
        effectSegmentControl.frame = CGRect(x: view.bounds.width - 200 - 10 , y: navigationHeight, width: 200, height: 30)
        publishButton.frame = CGRect(x: view.bounds.width - 44 - 20, y: view.bounds.height - 44 - 20, width: 44, height: 44)
        rtmpStream.view.frame = view.frame
        videoBitrateLabel.text = "video \(Int(videoBitrateSlider.value))/kbps"
        videoBitrateLabel.frame = CGRect(x: view.frame.width - 150 - 60, y: view.frame.height - 44 * 2 - 22, width: 150, height: 44)
        videoBitrateSlider.frame = CGRect(x: 20, y: view.frame.height - 44 * 2, width: view.frame.width - 44 - 60, height: 44)
        audioBitrateLabel.text = "audio \(Int(audioBitrateSlider.value))/kbps"
        audioBitrateLabel.frame = CGRect(x: view.frame.width - 150 - 60, y: view.frame.height - 44 - 22, width: 150, height: 44)
        audioBitrateSlider.frame = CGRect(x: 20, y: view.frame.height - 44, width: view.frame.width - 44 - 60, height: 44)
    }

    func rotateCamera(sender:UIBarButtonItem) {
        let position:AVCaptureDevicePosition = currentPosition == .Back ? .Front : .Back
        rtmpStream.attachCamera(AVMixer.deviceWithPosition(position))
        currentPosition = position
    }

    func toggleTorch(sender:UIBarButtonItem) {
        rtmpStream.torch = !rtmpStream.torch
    }

    func showPreference(sender:UIBarButtonItem) {
        let preference:PreferenceController = PreferenceController()
        preference.view.backgroundColor = UIColor(colorLiteralRed: 1.0, green: 1.0, blue: 1.0, alpha: 0.25)
        preference.view.frame = view.frame
        preference.modalPresentationStyle = .OverCurrentContext
        preference.modalTransitionStyle = .CrossDissolve
        presentViewController(preference, animated: true, completion: nil)
    }

    func onSliderValueChanged(slider:UISlider) {
        if (slider == audioBitrateSlider) {
            audioBitrateLabel.text = "audio \(Int(slider.value))/kbps"
            rtmpStream.audioSettings["bitrate"] = slider.value * 1024
        }
        if (slider == videoBitrateSlider) {
            videoBitrateLabel.text = "video \(Int(slider.value))/kbsp"
            rtmpStream.videoSettings["bitrate"] = slider.value * 1024
        }
    }

    func onClickPublish(sender:UIButton) {
        if (sender.selected) {
            UIApplication.sharedApplication().idleTimerDisabled = false
            rtmpConnection.close()
            rtmpConnection.removeEventListener(Event.RTMP_STATUS, selector:#selector(LiveViewController.rtmpStatusHandler(_:)), observer: self)
            sender.setTitle("●", forState: .Normal)
        } else {
            UIApplication.sharedApplication().idleTimerDisabled = true
            rtmpConnection.addEventListener(Event.RTMP_STATUS, selector:#selector(LiveViewController.rtmpStatusHandler(_:)), observer: self)
            rtmpConnection.connect(Preference.defaultInstance.uri!)
            sender.setTitle("■", forState: .Normal)
        }
        sender.selected = !sender.selected
    }
    
    func rtmpStatusHandler(notification:NSNotification) {
        let e:Event = Event.from(notification)
        if let data:ASObject = e.data as? ASObject , code:String = data["code"] as? String {
            switch code {
            case RTMPConnection.Code.ConnectSuccess.rawValue:
                rtmpStream!.publish(Preference.defaultInstance.streamName!)
                // sharedObject!.connect(rtmpConnection)
            default:
                break
            }
        }
    }

    func tapScreen(gesture: UIGestureRecognizer) {
        if let gestureView = gesture.view where gesture.state == .Ended {
            let touchPoint: CGPoint = gesture.locationInView(gestureView)
            let pointOfInterest: CGPoint = CGPoint(x: touchPoint.x/gestureView.bounds.size.width,
                y: touchPoint.y/gestureView.bounds.size.height)
            print("pointOfInterest: \(pointOfInterest)")
            rtmpStream.setPointOfInterest(pointOfInterest, exposure: pointOfInterest)
        }
    }

    func onEffectValueChanged(segment:UISegmentedControl) {
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
}