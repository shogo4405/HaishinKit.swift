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
    //前摄像 or 后摄像头
    var position = AVCaptureDevice.Position.front
    
    //@ScreenActor它的作用是为与屏幕相关的操作提供线程安全性和一致性。具体来说，它确保被标记的属性或方法在屏幕渲染上下文中执行（通常是主线程），避免因线程切换或并发访问导致的 UI 不一致或崩溃。 只会影响紧接其后的属性。如果你在两个属性之间插入空格或其他属性包装器，那么下一个属性将不受前一个包装器的影响
    @ScreenActor
    private var currentEffect: (any VideoEffect)?
    let front = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
    let connection = SRTConnection()
    var stream: SRTStream?
    var isVideoMirrored:Bool = true
    private lazy var mixer = MediaMixer()
    private lazy var audioCapture: AudioCapture = {
        let audioCapture = AudioCapture()
        audioCapture.delegate = self
        return audioCapture
    }()
    @ScreenActor
    private var videoScreenObject = VideoTrackScreenObject()
    
    @objc public func setSDK(view:UIView)
    {

        Task {  @ScreenActor in
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
            self.stream = SRTStream(connection: self.connection)
            guard let stream = self.stream else {
                return
            }
            await mixer.addOutput(stream)
            if let view = view as? (any HKStreamOutput) {
                await stream.addOutput(view)
            }
        }
        Task { @ScreenActor in
            videoScreenObject.cornerRadius = 16.0
            videoScreenObject.track = 1
            videoScreenObject.horizontalAlignment = .right
            videoScreenObject.layoutMargin = .init(top: 16, left: 0, bottom: 0, right: 16)
            videoScreenObject.size = .init(width: 160 * 2, height: 90 * 2)
             mixer.screen.size = .init(width: 720, height: 1280)
             mixer.screen.backgroundColor = UIColor.black.cgColor
            try?  mixer.screen.addChild(videoScreenObject)
        }
        Task { @ScreenActor in
            try? await mixer.attachAudio(AVCaptureDevice.default(for: .audio))
            //track 是多个摄像头的下标
            try? await mixer.attachVideo(front, track: 0){videoUnit in
                videoUnit.isVideoMirrored = true
            }
        }
        //TODO: 捕捉设备方向的变化
        NotificationCenter.default.addObserver(self, selector: #selector(on(_:)), name: UIDevice.orientationDidChangeNotification, object: nil)
        //TODO: 监听 AVAudioSession 的中断通知
        NotificationCenter.default.addObserver(self, selector: #selector(didInterruptionNotification(_:)), name: AVAudioSession.interruptionNotification, object: nil)
        //TODO: 用于捕捉音频路由变化（如耳机插入、蓝牙设备连接等）
        NotificationCenter.default.addObserver(self, selector: #selector(didRouteChangeNotification(_:)), name: AVAudioSession.routeChangeNotification, object: nil)
    }

    //捕捉设备方向的变化
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

        } else {
            setEnabledPreferredInputBuiltInMic(true)

        }

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
    @objc public func closeSrt()
    {
        UIApplication.shared.isIdleTimerDisabled = true
        self.closeSDK()
    }
    func closeSDK()
    {
        Task {
            //结束推流
            try? await connection.close()
            logger.info("conneciton.close")
        }
    }
    
    @objc public func openSrt()
    {
        UIApplication.shared.isIdleTimerDisabled = false
        Task {
            
            guard let stream = self.stream else {
                return
            }
            //开始推流
            await stream.publish()
            logger.info("conneciton.open")
        }
    }
    
    @objc public func shutdown()
    {
        Task {
            self.closeSDK()
            try? await mixer.attachAudio(nil)
            try? await mixer.attachVideo(nil, track: 0)
        }
 
        NotificationCenter.default.removeObserver(self)
    }
    /**
      配置推流URL
     */
    @objc public func setSrtUrl(url:String)
    {
        Task {
            try await connection.open(URL(string: url))
        }
    }
    /**
       切换前后摄像头
     */
    @objc public func attachVideo(position: AVCaptureDevice.Position)
    {
        Task {
            
        try? await mixer.attachVideo(AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)) {[weak self] videoUnit in
            guard let `self` = self else { return }
            self.position = position
            if(position == .front)
            {
                videoUnit.isVideoMirrored = isVideoMirrored
            }else{
                videoUnit.isVideoMirrored = false
            }
            
         }
       }
    }
    /**摄像头镜像开关
     */
    @objc public func isVideoMirrored(_ isVideoMirrored: Bool)
    {
        Task {
            if self.position == .front
            {
                let back = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                do {
                    //先切换到后摄像头, 再切换到前摄像头
                  try await mixer.attachVideo(back, track: 0) { backVideoUnit in
                   
                      self.attachVideo(isVideoMirrored)
                      
                  }
                } catch {
                  print(error)
                }
                
            }else{
                
                self.isVideoMirrored = isVideoMirrored
              
            }
        
        }
    }
    
    func attachVideo(_ isVideoMirrored:Bool)
    {
        Task {
            let front = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            //track 是多个摄像头的下标
            try? await mixer.attachVideo(front, track: 0){ videoUnit in
                videoUnit.isVideoMirrored = isVideoMirrored
            }
        }
    }
    /**设置 近  中 远 摄像头*/
    @objc public func switchCameraToType(cameraType:AVCaptureDevice.DeviceType)
    {
        Task {
            if self.position == .back
            {
                // .builtInWideAngleCamera
                let back = AVCaptureDevice.default(cameraType, for: .video, position: .back)
                //track 是多个摄像头的下标
                try? await mixer.attachVideo(back, track: 0){ videoUnit in
                    
                    videoUnit.isVideoMirrored = false
                }

            }
         
        }
        
    }

}
extension TFIngest: AudioCaptureDelegate {
    // MARK: AudioCaptureDelegate
    nonisolated func audioCapture(_ audioCapture: AudioCapture, buffer: AVAudioBuffer, time: AVAudioTime) {
        Task { await mixer.append(buffer, when: time) }
    }
}
