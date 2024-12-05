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
    //是否已经在录制
    var isRecording:Bool = false

    //@ScreenActor它的作用是为与屏幕相关的操作提供线程安全性和一致性。具体来说，它确保被标记的属性或方法在屏幕渲染上下文中执行（通常是主线程），避免因线程切换或并发访问导致的 UI 不一致或崩溃。 只会影响紧接其后的属性。如果你在两个属性之间插入空格或其他属性包装器，那么下一个属性将不受前一个包装器的影响
    @ScreenActor
    private var currentEffect: (any VideoEffect)?
    let front = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
    let connection = SRTConnection()
    var stream: SRTStream?
    var recorder: HKStreamRecorder?
    var isVideoMirrored:Bool = true
    private lazy var mixer = MediaMixer()
    private lazy var audioCapture: AudioCapture = {
        let audioCapture = AudioCapture()
        audioCapture.delegate = self
        return audioCapture
    }()
    @ScreenActor
    private var videoScreenObject = VideoTrackScreenObject()
    
    @objc public func setSDK(view:UIView,
                             videoSize:CGSize,
                             videoFrameRate:CGFloat,
                             videoBitRate:Int)
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
            //录制管理者
            self.recorder = HKStreamRecorder()
            
            guard let stream = self.stream else {
                return
            }
            guard let recorder = self.recorder else {
                return
            }
            await stream.addOutput(recorder)
        
            await mixer.addOutput(stream)
            if let view = view as? (any HKStreamOutput) {
                await stream.addOutput(view)
            }
            
            var videoSettings = await stream.videoSettings
            ///// 视频的码率，单位是 bps
            videoSettings.bitRate = videoBitRate
            ///// /// 视频的分辨率，宽高务必设定为 2 的倍数，否则解码播放时可能出现绿边(这个videoSizeRespectingAspectRatio设置为YES则可能会改变)
            videoSettings.videoSize = videoSize
            await stream.setVideoSettings(videoSettings)
            
        }
        Task { @ScreenActor in
             //screen 离屏渲染对象。
             mixer.screen.size = videoSize
             mixer.screen.backgroundColor = UIColor.black.cgColor
            // 视频的帧率，即 fps
            await mixer.setFrameRate(videoFrameRate)
            
            videoScreenObject.cornerRadius = 16.0
            videoScreenObject.track = 1
            videoScreenObject.horizontalAlignment = .right
            videoScreenObject.layoutMargin = .init(top: 16, left: 0, bottom: 0, right: 16)
            videoScreenObject.size = .init(width: 160 * 2, height: 90 * 2)
            //本地显示的渲染配置
            try? mixer.screen.addChild(videoScreenObject)
 
        }
        Task { @ScreenActor in
            try? await mixer.attachAudio(AVCaptureDevice.default(for: .audio))
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
        self.closePush()
    }
    func closePush()
    {
        Task {  @ScreenActor in
            //结束推流
            try? await connection.close()
            logger.info("conneciton.close")
        }
    }
    
    @objc public func openSrt()
    {
        UIApplication.shared.isIdleTimerDisabled = false
        Task {  @ScreenActor in
            
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
        Task {  @ScreenActor in
            
            if(self.isRecording)
            {
                self.recording(false)
            }
            
            //结束推流
            self.closePush()
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
        Task {  @ScreenActor in
            try await connection.open(URL(string: url))
        }
    }
    /**
       切换前后摄像头
     */
    @objc public func attachVideo(position: AVCaptureDevice.Position)
    {
        Task {  @ScreenActor in
            
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
        Task {  @ScreenActor in
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
        Task {  @ScreenActor in
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
        Task {  @ScreenActor in
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
    /**录制视频**/
    @objc public func recording(_ isRecording:Bool)
    {
        Task {  @ScreenActor in
            guard let recorder = self.recorder else {
                return
            }
            self.isRecording = isRecording
            if isRecording {
                print("startRecording")
                try await recorder.startRecording(nil)
             
                
//                try await recorder.startRecording(URL(string: "dir/sample.mp4"), settings: [
//                    AVMediaType.audio: [
//                        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
//                        AVSampleRateKey: 0,
//                        AVNumberOfChannelsKey: 0,
//                    ],
//                    AVMediaType.video: [
//                        AVVideoCodecKey: AVVideoCodecType.h264,
//                        AVVideoHeightKey: 0,
//                        AVVideoWidthKey: 0,
//                    
//                    ]
//                ])
            }else{
                
                do {
                    let recordingURL = try await recorder.stopRecording()
                    // 处理录制文件的 URL
                    print("Recording saved at: \(recordingURL)")
                } catch {
                    
                    print("error: \(error)")
                }


                
            }
            
        }
        
    }
    
    //-----------------------------------------------
    
    var effectsList: [TFEffect] = []
    
    @objc public func registerVideoEffect(_ state:NSInteger)  {
        Task {
            
            //默认
            if state == 0 {
                
                for effect in effectsList {
                    //清空所有滤层
                  _ = await mixer.screen.unregisterVideoEffect(effect)
                }

                effectsList.removeAll()
            } else if (state == 1)
            {
                for effect in effectsList {
                    if effect.state == state {
                        return
                    }
                }
                //加有水印
                let effect = TFPronamaEffect()
                effect.state = state
                effectsList.append(effect)
             _ = await mixer.screen.registerVideoEffect(effect)
      
            }else{
                for effect in effectsList {
                    if effect.state == state {
                        return
                    }
                }
                //黑白
                let effect = TFMonochromeEffect()
                effect.state = state
                effectsList.append(effect)
                _ = await mixer.screen.registerVideoEffect(effect)
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
 class TFEffect: VideoEffect {
    var state:NSInteger = -1
    func execute(_ image: CIImage) -> CIImage {
      
        return image
    }
}
//黑白
final class TFMonochromeEffect: TFEffect {
    let filter: CIFilter? = CIFilter(name: "CIColorMonochrome")

    override func execute(_ image: CIImage) -> CIImage {
        guard let filter: CIFilter = filter else {
            return image
        }
        filter.setValue(image, forKey: "inputImage")
        filter.setValue(CIColor(red: 0.75, green: 0.75, blue: 0.75), forKey: "inputColor")
        filter.setValue(1.0, forKey: "inputIntensity")
        
        guard let outputImage = filter.outputImage else {
            return image
        }
        return outputImage
    }
}

//加水印
final class TFPronamaEffect: TFEffect {
    
    let filter: CIFilter? = CIFilter(name: "CISourceOverCompositing")

    var extent = CGRect.zero {
        didSet {
            if extent == oldValue {
                return
            }
            UIGraphicsBeginImageContext(extent.size)
            let image = UIImage(named: "Icon.png")!
            image.draw(at: CGPoint(x: 50, y: 50))
            pronama = CIImage(image: UIGraphicsGetImageFromCurrentImageContext()!, options: nil)
            UIGraphicsEndImageContext()
        }
    }
    var pronama: CIImage?

    override func execute(_ image: CIImage) -> CIImage {
        guard let filter: CIFilter = filter else {
            return image
        }
        extent = image.extent
        filter.setValue(pronama!, forKey: "inputImage")
        filter.setValue(image, forKey: "inputBackgroundImage")
        
        guard let outputImage = filter.outputImage else {
            return image
        }
        return outputImage
    }
}
