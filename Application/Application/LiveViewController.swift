import lf
import UIKit
import AVFoundation

final class LiveViewController: UIViewController {
    let url:String = "rtmp://192.168.179.5/live"
    let streamName:String = "live"

    var rtmpConnection:RTMPConnection = RTMPConnection()
    var rtmpStream:RTMPStream!
    var sharedObject:RTMPSharedObject!
    var currentEffect:VisualEffect? = nil

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
        let segment:UISegmentedControl = UISegmentedControl(items: ["None", "Monochrome", "Sepia"])
        segment.tintColor = UIColor.whiteColor()
        return segment
    }()

    var currentPosition:AVCaptureDevicePosition = AVCaptureDevicePosition.Back

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "lf.TestApplication"

        videoBitrateSlider.addTarget(self, action: "onSliderValueChanged:", forControlEvents: .ValueChanged)
        audioBitrateSlider.addTarget(self, action: "onSliderValueChanged:", forControlEvents: .ValueChanged)
        effectSegmentControl.addTarget(self, action: "onEffectValueChanged:", forControlEvents: .ValueChanged)

        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Torch", style: .Plain, target: self, action: "toggleTorch:")
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Camera", style: .Plain, target: self, action: "rotateCamera:")

        rtmpStream = RTMPStream(rtmpConnection: rtmpConnection)
        rtmpStream.syncOrientation = true
        rtmpStream.attachAudio(AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeAudio))
        rtmpStream.attachCamera(AVCaptureSessionManager.deviceWithPosition(.Back))
        // rtmpStream.attachScreen(ScreenCaptureSession())

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
        let navigationHeight:CGFloat = view.bounds.width < view.bounds.height ? 64 : 44
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
            sender.setTitle("●", forState: .Normal)
        } else {
            UIApplication.sharedApplication().idleTimerDisabled = true
            rtmpConnection.addEventListener(Event.RTMP_STATUS, selector:"rtmpStatusHandler:", observer: self)
            rtmpConnection.connect(url)
            sender.setTitle("■", forState: .Normal)
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

    func onEffectValueChanged(segment:UISegmentedControl) {
        if let currentEffect:VisualEffect = currentEffect {
            rtmpStream.unregisterEffect(video: currentEffect)
        }
        switch segment.selectedSegmentIndex {
        case 1:
            currentEffect = MonochromeEffect()
            rtmpStream.registerEffect(video: currentEffect!)
        case 2:
            currentEffect = SepiaEffect()
            rtmpStream.registerEffect(video: currentEffect!)
        default:
            break
        }
    }
}

final class SepiaEffect: VisualEffect {
    let filter:CIFilter? = CIFilter(name: "CISepiaTone")
    
    override func execute(image: CIImage) -> CIImage {
        guard let filter:CIFilter = filter else {
            return image
        }
        filter.setValue(image, forKey: "inputImage")
        filter.setValue(0.8, forKey: "inputIntensity")
        return filter.outputImage!
    }
}

final class MonochromeEffect: VisualEffect {
    let filter:CIFilter? = CIFilter(name: "CIColorMonochrome")

    override func execute(image: CIImage) -> CIImage {
        guard let filter:CIFilter = filter else {
            return image
        }
        filter.setValue(image, forKey: "inputImage")
        filter.setValue(CIColor(red: 0.75, green: 0.75, blue: 0.75), forKey: "inputColor")
        filter.setValue(1.0, forKey: "inputIntensity")
        return filter.outputImage!
    }
}

