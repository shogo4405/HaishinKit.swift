import lf
import UIKit
import AVFoundation

final class LiveViewController: UIViewController {
    
    let url:String = "rtmp://test:test@192.168.179.4/live"
    let streamName:String = "live"

    var rtmpConnection:RTMPConnection = RTMPConnection()
    var rtmpStream:RTMPStream!

    let touchView: UIView! = UIView()
    
    var publishButton:UIButton = {
        let button:UIButton = UIButton()
        button.backgroundColor = UIColor.blueColor()
        button.setTitle("start", forState: .Normal)
        button.layer.masksToBounds = true
        return button
    }()

    var audioBitrateSlider:UISlider = {
        let slider:UISlider = UISlider()
        slider.minimumValue = 0.0;
        slider.maximumValue = 120;
        return slider
    }()

    var currentPosition:AVCaptureDevicePosition = AVCaptureDevicePosition.Back

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "lf.TestApplication"

        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Torch", style: .Plain, target: self, action: "toggleTorch:")
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Switch", style: .Plain, target: self, action: "rotateCamera:")

        rtmpStream = RTMPStream(rtmpConnection: rtmpConnection)
        rtmpStream.syncOrientation = true
        rtmpStream.attachAudio(AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeAudio))
        rtmpStream.attachCamera(AVCaptureSessionManager.deviceWithPosition(.Back))
        
        rtmpStream.sessionManager.continuousAutofocus = true
        rtmpStream.sessionManager.continuousExposure = true
        
        publishButton.addTarget(self, action: "onClickPublish:", forControlEvents: .TouchUpInside)

        view.addSubview(rtmpStream.view)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: "tapScreen:")
        touchView.addGestureRecognizer(tapGesture)
        touchView.frame = view.frame
        touchView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]

        view.addSubview(touchView)
        view.addSubview(publishButton)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        let navigationHeight:CGFloat = view.bounds.width < view.bounds.height ? 64 : 0
        publishButton.frame = CGRect(x: view.bounds.width - 44 - 22, y: navigationHeight + 44, width: 44, height: 44)
        rtmpStream.view.frame = view.frame
    }

    func rotateCamera(sender:UIBarButtonItem) {
        let position:AVCaptureDevicePosition = currentPosition == .Back ? .Front : .Back
        rtmpStream.attachCamera(AVCaptureSessionManager.deviceWithPosition(position))
        currentPosition = position
    }

    func onClickPublish(sender:UIButton) {
        if (sender.selected) {
            UIApplication.sharedApplication().idleTimerDisabled = false
            rtmpConnection.close()
            rtmpConnection.removeEventListener(Event.RTMP_STATUS, selector:"rtmpConnection_rtmpStatusHandler", observer: self)
            sender.setTitle("start", forState: .Normal)
        } else {
            UIApplication.sharedApplication().idleTimerDisabled = true
            rtmpConnection.addEventListener(Event.RTMP_STATUS, selector:"rtmpConnection_rtmpStatusHandler:", observer: self)
            rtmpConnection.connect(url)
            sender.setTitle("stop", forState: .Normal)
        }
        sender.selected = !sender.selected
    }

    func toggleTorch(sender:UIBarButtonItem) {
        rtmpStream.sessionManager.torch = !rtmpStream.sessionManager.torch
    }
    
    func rtmpConnection_rtmpStatusHandler(notification:NSNotification) {
        let e:Event = Event.from(notification)
        if let data:ECMAObject = e.data as? ECMAObject {
            if let code:String = data["code"] as? String {
                print(code)
                switch code {
                case RTMPConnection.Code.ConnectSuccess.rawValue:
                    rtmpStream!.publish(streamName)
                default:
                    break
                }
            }
        }
    }
    
    // MARK: - gestures
    func tapScreen(gesture: UIGestureRecognizer) {
        if let gestureView = gesture.view where gesture.state == .Ended {
            let touchPoint: CGPoint = gesture.locationInView(gestureView)
            let pointOfInterest: CGPoint = CGPoint(x: touchPoint.x/gestureView.bounds.size.width,
                y: touchPoint.y/gestureView.bounds.size.height)
            
            print("pointOfInterest: \(pointOfInterest)")
            rtmpStream.sessionManager.focusPointOfInterest = pointOfInterest
            rtmpStream.sessionManager.exposurePointOfInterest = pointOfInterest
        }
    }
    
}
