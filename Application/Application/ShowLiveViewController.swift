import Foundation
import lf
import UIKit
import AVFoundation

final class ShowLiveViewController: UIViewController {
    
    let url:String = "rtmp://localhost/test"
    let streamName:String = "test/0"
    
    var goLiveButton: UIButton!
    var rtmpConnection:RTMPConnection = RTMPConnection()
    var rtmpStream:RTMPStream!
    var previewLayer:AVSampleBufferDisplayLayer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        rtmpStream = RTMPStream(rtmpConnection: rtmpConnection)
        goLiveButton = UIButton(frame: CGRectMake(0, 0, 44, 44))
        goLiveButton.backgroundColor = UIColor.blueColor()
        goLiveButton.setTitle("start", forState: .Normal)
        goLiveButton.layer.masksToBounds = true
        goLiveButton.layer.position = CGPoint(x: self.view.bounds.width - 32, y: 32)
        goLiveButton.addTarget(self, action: "goLiveButton_onClick:", forControlEvents: .TouchUpInside)
        
        previewLayer = rtmpStream.display
        previewLayer.frame = getPreviewLayerRect()
        previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
        
        view.layer.addSublayer(previewLayer!)
        view.addSubview(goLiveButton)
    }
    
    override func willAnimateRotationToInterfaceOrientation(toInterfaceOrientation:
        UIInterfaceOrientation, duration: NSTimeInterval) {
            goLiveButton.layer.position = CGPoint(x: self.view.bounds.width - 32, y: 32)
            previewLayer.frame = getPreviewLayerRect()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    func goLiveButton_onClick(sender:UIButton) {
        
        if (goLiveButton.selected) {
            UIApplication.sharedApplication().idleTimerDisabled = false
            rtmpConnection.close()
            rtmpConnection.removeEventListener("rtmpStatus", selector:"rtmpConnection_rtmpStatusHandler", observer: self)
            goLiveButton.setTitle("start", forState: .Normal)
        } else {
            UIApplication.sharedApplication().idleTimerDisabled = true
            rtmpConnection.addEventListener("rtmpStatus", selector:"rtmpConnection_rtmpStatusHandler:", observer: self)
            rtmpConnection.connect(url)
            goLiveButton.setTitle("stop", forState: .Normal)
        }
        
        goLiveButton.selected = !goLiveButton.selected
    }
    
    func rtmpConnection_rtmpStatusHandler(notification:NSNotification) {
        let e:Event = Event.from(notification)
        if let data:ECMAObject = e.data as? ECMAObject {
            if let code:String = data["code"] as? String {
                switch code {
                case "NetConnection.Connect.Success":
                    rtmpStream!.play(streamName)
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
