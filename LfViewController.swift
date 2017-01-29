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
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.setCameraStream()
    }
    
    private func setCameraStream() {
        
        rtmpConnection = RTMPConnection()
        rtmpStream = RTMPStream(connection: rtmpConnection)
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
        
        let lfView = LFView(frame: view.bounds)
        lfView.videoGravity = AVLayerVideoGravityResizeAspectFill
        lfView.attachStream(rtmpStream)
        
        // add ViewController#view
        let closeButton = UIButton(frame: CGRect(x: 150, y: 200, width: 100, height: 100))
        closeButton.setTitle("Close", for: UIControlState.normal)
        closeButton.setTitleColor(UIColor.red, for: UIControlState.normal)
        closeButton.addTarget(self, action: #selector(LfViewController.close), for: UIControlEvents.touchUpInside)
        
        lfView.addSubview(closeButton)
        view.addSubview(lfView)
    }
    
    dynamic private func close() {
        self.dismiss(animated: true, completion: nil)
    }
    
}
