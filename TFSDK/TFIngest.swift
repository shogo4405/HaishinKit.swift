//
//  TFIngest.swift
//  SRTHaishinKit
//
//  Created by moRui on 2024/12/3.
//

import AVFoundation
import HaishinKit
import Photos
import UIKit
import VideoToolbox

public class TFIngest: NSObject {
    //@ScreenActor它的作用是为与屏幕相关的操作提供线程安全性和一致性。具体来说，它确保被标记的属性或方法在屏幕渲染上下文中执行（通常是主线程），避免因线程切换或并发访问导致的 UI 不一致或崩溃。
    @ScreenActor
    private var currentEffect: (any VideoEffect)?
    private var currentPosition: AVCaptureDevice.Position = .front
    private var retryCount: Int = 0
    private var preferedStereo = false
    private let netStreamSwitcher: HKStreamSwitcher = .init()
    private lazy var mixer = MediaMixer()
    private lazy var audioCapture: AudioCapture = {
        let audioCapture = AudioCapture()
        audioCapture.delegate = self
        return audioCapture
    }()
    @ScreenActor
    private var videoScreenObject = VideoTrackScreenObject()
    
    @objc public func disappear()
    {
        logger.info("viewWillDisappear")
        Task {
            audioCapture.stopRunning()
            await netStreamSwitcher.close()
         
            try? await mixer.attachAudio(nil)
            try? await mixer.attachVideo(nil, track: 0)
            try? await mixer.attachVideo(nil, track: 1)
        }
 
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc public func setSDK(view:UIView)
    {
         /**
          func fetchVideoMixerSettings() async {} 或者  Task{}

            必须在 async或者Task{} 函数中使用   使用 await 可以让异步代码看起来像同步代码，易于阅读和维护。
          */
        Task { @ScreenActor in
            
            if let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene {
                let orientation = await windowScene.interfaceOrientation
                if let videoOrientation = DeviceUtil.videoOrientation(by: orientation) {
                    await mixer.setVideoOrientation(videoOrientation)
                }
            }
            
            await mixer.setMonitoringEnabled(DeviceUtil.isHeadphoneConnected())
            var videoMixerSettings = await mixer.videoMixerSettings
            videoMixerSettings.mode = .offscreen
            await mixer.setVideoMixerSettings(videoMixerSettings)
            await netStreamSwitcher.setPreference(Preference.default)
            if let stream = await netStreamSwitcher.stream {
                await mixer.addOutput(stream)
                if let view = view as? (any HKStreamOutput) {
                    await stream.addOutput(view)
                }
            }

            videoScreenObject.cornerRadius = 16.0
            videoScreenObject.track = 1
            videoScreenObject.horizontalAlignment = .right
            videoScreenObject.layoutMargin = .init(top: 16, left: 0, bottom: 0, right: 16)
            videoScreenObject.size = .init(width: 160 * 2, height: 90 * 2)
             mixer.screen.size = .init(width: 720, height: 1280)
            
             mixer.screen.backgroundColor = UIColor.black.cgColor
            try? mixer.screen.addChild(videoScreenObject)
   
            let back = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentPosition)
            try? await mixer.attachVideo(back, track: 0)
            try? await mixer.attachAudio(AVCaptureDevice.default(for: .audio))
            let front = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            try? await mixer.attachVideo(front, track: 1) { videoUnit in
                videoUnit.isVideoMirrored = true
            }
            
            //捕捉设备方向的变化
            NotificationCenter.default.addObserver(self, selector: #selector(on(_:)), name: UIDevice.orientationDidChangeNotification, object: nil)
            //NotificationCenter 监听 AVAudioSession 的中断通知
            NotificationCenter.default.addObserver(self, selector: #selector(didInterruptionNotification(_:)), name: AVAudioSession.interruptionNotification, object: nil)
            //AVAudioSession.routeChangeNotification，用于捕捉音频路由变化（如耳机插入、蓝牙设备连接等）
            NotificationCenter.default.addObserver(self, selector: #selector(didRouteChangeNotification(_:)), name: AVAudioSession.routeChangeNotification, object: nil)
        }



    }

    
    @objc
    private func on(_ notification: Notification) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return
        }

        let orientation = windowScene.interfaceOrientation
        guard let videoOrientation = DeviceUtil.videoOrientation(by: orientation) else {
            return
        }

        Task {
            await mixer.setVideoOrientation(videoOrientation)
        }
    }
    //监听 AVAudioSession 的中断通知
    @objc
    private func didInterruptionNotification(_ notification: Notification) {
        logger.info(notification)
    }
   //用于捕捉音频路由变化（如耳机插入、蓝牙设备连接等）
    @objc
    private func didRouteChangeNotification(_ notification: Notification) {
        logger.info(notification)
        if AVAudioSession.sharedInstance().inputDataSources?.isEmpty == true {
            setEnabledPreferredInputBuiltInMic(false)
//            audioMonoStereoSegmentCOntrol.isHidden = true
//            audioDevicePicker.isHidden = true
        } else {
            setEnabledPreferredInputBuiltInMic(true)
//            audioMonoStereoSegmentCOntrol.isHidden = false
//            audioDevicePicker.isHidden = false
        }
//        audioDevicePicker.reloadAllComponents()
        Task {
            if DeviceUtil.isHeadphoneDisconnected(notification) {
                await mixer.setMonitoringEnabled(false)
            } else {
                await mixer.setMonitoringEnabled(DeviceUtil.isHeadphoneConnected())
            }
        }
    }
    
    private func setEnabledPreferredInputBuiltInMic(_ isEnabled: Bool) {
        let session = AVAudioSession.sharedInstance()
        do {
            if isEnabled {
                guard
                    let availableInputs = session.availableInputs,
                    let builtInMicInput = availableInputs.first(where: { $0.portType == .builtInMic }) else {
                    return
                }
                try session.setPreferredInput(builtInMicInput)
            } else {
                try session.setPreferredInput(nil)
            }
        } catch {
        }
    }
}
extension TFIngest: AudioCaptureDelegate {
    // MARK: AudioCaptureDelegate
    nonisolated func audioCapture(_ audioCapture: AudioCapture, buffer: AVAudioBuffer, time: AVAudioTime) {
        Task { await mixer.append(buffer, when: time) }
    }
}
