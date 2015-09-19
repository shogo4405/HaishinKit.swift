import lf
import UIKit
import AVFoundation

final class GoLiveViewController: UIViewController {
    
    let url:String = "rtmp://localhost/live"
    let streamName:String = "test"
    
    var startButton, stopButton:UIButton!
    var rtmpConnection:RTMPConnection = RTMPConnection()
    var rtmpStream:RTMPStream?
    var previewLayer:AVCaptureVideoPreviewLayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        rtmpStream = RTMPStream(rtmpConnection: rtmpConnection)
        rtmpStream!.attachAudio(AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeAudio))
        rtmpStream!.attachCamera(AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo))
        
        startButton = UIButton(frame: CGRectMake(0, 0, 44, 44))
        startButton.backgroundColor = UIColor.blueColor()
        startButton.setTitle("start", forState: .Normal)
        startButton.layer.masksToBounds = true
        startButton.layer.position = CGPoint(x: self.view.bounds.width - 32, y: 32)
        startButton.addTarget(self, action: "startButton_onClick:", forControlEvents: .TouchUpInside)
        
        stopButton = UIButton(frame: CGRectMake(0, 0, 44, 44))
        stopButton.backgroundColor = UIColor.grayColor();
        stopButton.layer.masksToBounds = true
        stopButton.setTitle("stop", forState: .Normal)
        stopButton.layer.position = CGPoint(x: self.view.bounds.width - 32, y: 32 + 44 + 8)
        stopButton.addTarget(self, action: "stopButton_onClick:", forControlEvents: .TouchUpInside)
        
        previewLayer = rtmpStream!.toPreviewLayer()
        previewLayer!.frame = getPreviewLayerRect()
        previewLayer!.videoGravity = AVLayerVideoGravityResizeAspectFill
        
        view.layer.addSublayer(previewLayer!)
        
        self.view.addSubview(self.startButton)
        self.view.addSubview(self.stopButton)
    }
    
    override func willAnimateRotationToInterfaceOrientation(toInterfaceOrientation:
        UIInterfaceOrientation, duration: NSTimeInterval) {
        startButton.layer.position = CGPoint(x: self.view.bounds.width - 32, y: 32)
        stopButton.layer.position =  CGPoint(x: self.view.bounds.width - 32, y: 32 + 44 + 8)
        previewLayer!.frame = getPreviewLayerRect()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    func startButton_onClick(sender:UIButton) {
        UIApplication.sharedApplication().idleTimerDisabled = true
        rtmpConnection.addEventListener("rtmpStatus", selector:"rtmpConnection_rtmpStatusHandler:", observer: self)
        rtmpConnection.connect(url)
    }
    
    func stopButton_onClick(sender:UIButton) {
        UIApplication.sharedApplication().idleTimerDisabled = false
        rtmpConnection.close()
        rtmpConnection.removeEventListener("rtmpStatus", selector:"rtmpConnection_rtmpStatusHandler", observer: self)
    }
    
    func rtmpConnection_rtmpStatusHandler(notification:NSNotification) {
        let e:Event = Event.from(notification)
        if let data:ECMAObject = e.data as? ECMAObject {
            if let code:String = data["code"] as? String {
                switch code {
                case "NetConnection.Connect.Success":
                    rtmpStream!.publish(streamName)
                    break
                default:
                    break
                }
            }
        }
    }

    func getPreviewLayerRect() -> CGRect{
        switch UIApplication.sharedApplication().statusBarOrientation {
        case .Portrait, .PortraitUpsideDown:
            return CGRectMake(0, 0, view.bounds.width, view.bounds.width * 9 / 16)
        case .LandscapeRight, .LandscapeLeft:
            return view.bounds
        case .Unknown:
            return view.bounds
        }
    }
}
