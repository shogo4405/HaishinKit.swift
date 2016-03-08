import lf
import UIKit
import AVFoundation

final class LiveViewController: UIViewController {
    
    let url:String = "rtmp://test:test@192.168.179.5/live"
    let streamName:String = "live"

    var rtmpConnection:RTMPConnection = RTMPConnection()
    var rtmpStream:RTMPStream!
    var sharedObject:RTMPSharedObject!

    let touchView: UIView! = UIView()

    var consoleView:UITextView = {
        let view:UITextView = UITextView()
        view.backgroundColor = UIColor.clearColor()
        return view
    }()
    
    var publishButton:UIButton = {
        let button:UIButton = UIButton()
        button.backgroundColor = UIColor.blueColor()
        button.setTitle("start", forState: .Normal)
        button.layer.masksToBounds = true
        return button
    }()

    var videoBitrateLabel:UILabel = UILabel()
    var videoBitrateSlider:UISlider = {
        let slider:UISlider = UISlider()
        slider.minimumValue = 32
        slider.maximumValue = 1024
        return slider
    }()

    var audioBitrateLabel:UILabel = UILabel()
    var audioBitrateSlider:UISlider = {
        let slider:UISlider = UISlider()
        slider.minimumValue = 16
        slider.maximumValue = 120
        return slider
    }()

    var currentPosition:AVCaptureDevicePosition = AVCaptureDevicePosition.Back

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "lf.TestApplication"

        videoBitrateSlider.addTarget(self, action: "onSliderValueChanged:", forControlEvents: .ValueChanged)
        audioBitrateSlider.addTarget(self, action: "onSliderValueChanged:", forControlEvents: .ValueChanged)

        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Torch", style: .Plain, target: self, action: "toggleTorch:")
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Camera", style: .Plain, target: self, action: "rotateCamera:")

        rtmpStream = RTMPStream(rtmpConnection: rtmpConnection)
        rtmpStream.syncOrientation = true
        rtmpStream.attachAudio(AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeAudio))
        rtmpStream.attachCamera(AVCaptureSessionManager.deviceWithPosition(.Back))
        
        rtmpStream.captureSettings = [
            "continuousAutofocus": true,
            "continuousExposure": true,
        ]
        
        publishButton.addTarget(self, action: "onClickPublish:", forControlEvents: .TouchUpInside)

        view.addSubview(rtmpStream.view)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: "tapScreen:")
        touchView.addGestureRecognizer(tapGesture)
        touchView.frame = view.frame
        touchView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]

        videoBitrateSlider.value = Float(RTMPStream.defaultVideoBitrate) / 1024
        audioBitrateSlider.value = Float(RTMPStream.defaultAudioBitrate) / 1024

        view.addSubview(consoleView)
        view.addSubview(touchView)
        view.addSubview(videoBitrateLabel)
        view.addSubview(videoBitrateSlider)
        view.addSubview(audioBitrateLabel)
        view.addSubview(audioBitrateSlider)
        view.addSubview(publishButton)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        let navigationHeight:CGFloat = view.bounds.width < view.bounds.height ? 64 : 0
        publishButton.frame = CGRect(x: view.bounds.width - 44 - 22, y: navigationHeight + 44, width: 44, height: 44)
        rtmpStream.view.frame = view.frame
        consoleView.frame = CGRect(x: 0, y: navigationHeight, width: view.frame.width, height: view.frame.height - navigationHeight)
        videoBitrateLabel.text = "video \(Int(videoBitrateSlider.value))/kbps"
        videoBitrateLabel.frame = CGRect(x: view.frame.width - 150, y: view.frame.height - 44 * 2 - 22, width: 150, height: 44)
        videoBitrateSlider.frame = CGRect(x: 10, y: view.frame.height - 44 * 2, width: view.frame.width - 20, height: 44)
        audioBitrateLabel.text = "audio \(Int(audioBitrateSlider.value))/kbps"
        audioBitrateLabel.frame = CGRect(x: view.frame.width - 150, y: view.frame.height - 44 - 22, width: 150, height: 44)
        audioBitrateSlider.frame = CGRect(x: 10, y: view.frame.height - 44, width: view.frame.width - 20, height: 44)
    }

    func rotateCamera(sender:UIBarButtonItem) {
        let position:AVCaptureDevicePosition = currentPosition == .Back ? .Front : .Back
        rtmpStream.attachCamera(AVCaptureSessionManager.deviceWithPosition(position))
        currentPosition = position
    }

    func toggleTorch(sender:UIBarButtonItem) {
        rtmpStream.torch = !rtmpStream.torch
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
            rtmpConnection.removeEventListener(Event.RTMP_STATUS, selector:"rtmpStatusHandler", observer: self)
            sender.setTitle("start", forState: .Normal)
        } else {
            UIApplication.sharedApplication().idleTimerDisabled = true
            rtmpConnection.addEventListener(Event.RTMP_STATUS, selector:"rtmpStatusHandler:", observer: self)
            rtmpConnection.connect(url)
            sender.setTitle("stop", forState: .Normal)
        }
        sender.selected = !sender.selected
    }
    
    func rtmpStatusHandler(notification:NSNotification) {
        let e:Event = Event.from(notification)
        if let data:ASObject = e.data as? ASObject , code:String = data["code"] as? String {
            switch code {
            case RTMPConnection.Code.ConnectSuccess.rawValue:
                rtmpStream!.publish(streamName)
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
    
}
