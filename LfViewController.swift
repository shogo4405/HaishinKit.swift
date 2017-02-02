//
//  LfViewController.swift
//  lf
//
//  Created by Shogo Endo on 2017/01/29.
//  Copyright © 2017年 Shogo Endo. All rights reserved.
//

import UIKit
import lf
import AVFoundation
import VideoToolbox

class LfViewController: UIViewController {
    
    private var rtmpConnection: RTMPConnection!
    private var rtmpStream: RTMPStream!

    private var lfView:LFView?

    override func viewDidLoad() {
        super.viewDidLoad()
        // let lfView = LFView(frame: view.bounds)

        lfView = LFView(frame: view.bounds)
        lfView?.videoGravity = AVLayerVideoGravityResizeAspectFill

        // add ViewController#view
        let closeButton = UIButton(frame: CGRect(x: 150, y: 200, width: 100, height: 100))
        closeButton.setTitle("Close", for: UIControlState.normal)
        closeButton.setTitleColor(UIColor.red, for: UIControlState.normal)
        closeButton.addTarget(self, action: #selector(LfViewController.close), for: UIControlEvents.touchUpInside)
        
        let tButton = UIButton(frame: CGRect(x: 150, y: 500, width: 100, height: 100))
        tButton.setTitle("T", for: UIControlState.normal)
        tButton.setTitleColor(UIColor.red, for: UIControlState.normal)
        tButton.addTarget(self, action: #selector(LfViewController.toggle), for: UIControlEvents.touchUpInside)
        
        lfView?.addSubview(tButton)
        lfView?.addSubview(closeButton)
        view.addSubview(lfView!)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.setCameraStream()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        rtmpStream.dispose()
    }
    
    private func setCameraStream() {
        
        rtmpConnection = RTMPConnection()
        rtmpStream = RTMPStream(connection: rtmpConnection)
        rtmpStream.syncOrientation = true
        let sampleRate:Double = 48_000 // or 44_100
        do {
            try AVAudioSession.sharedInstance().setPreferredSampleRate(sampleRate)
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord)
            try AVAudioSession.sharedInstance().setMode(AVAudioSessionModeVideoChat)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
        }
        
        rtmpStream.captureSettings = [
            "fps": 30, // FPS
            "sessionPreset": AVCaptureSessionPresetMedium, // input video width/height
            "continuousAutofocus": false, // use camera autofocus mode
            "continuousExposure": false, //  use camera exposure mode
        ]
        rtmpStream.audioSettings = [
            "muted": false, // mute audio
            "bitrate": 32 * 1024,
            "sampleRate": sampleRate,
        ]
        rtmpStream.videoSettings = [
            "width": 360, // video output width
            "height": 640, // video output height
            "bitrate": 160 * 1024, // video output bitrate
            //"bitrate": 512 * 1024, // video output bitrate
            "profileLevel": kVTProfileLevel_H264_High_4_2, // H264 Profile require "import VideoToolbox"
            "maxKeyFrameIntervalDuration": 2, // key frame / sec
        ]
        
        rtmpStream.attachAudio(AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeAudio), automaticallyConfiguresApplicationAudioSession: false)
        rtmpStream.attachCamera(DeviceUtil.device(withPosition: .back))

        lfView?.attachStream(rtmpStream)
    }
    
    
    var cameraPosition:AVCaptureDevicePosition = AVCaptureDevicePosition.back
    dynamic private func toggle() {
        cameraPosition = cameraPosition == .back ? .front : .back
        rtmpStream.attachCamera(DeviceUtil.device(withPosition: cameraPosition))
    }
    
    dynamic private func close() {
        self.dismiss(animated: true, completion: nil)
    }
    
}
