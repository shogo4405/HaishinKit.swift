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

@objc public enum TFStreamMode: Int {
    case rtmp = 0
    case srt = 1
}
public class TFIngest: NSObject {
    //前摄像 or 后摄像头
    var position = AVCaptureDevice.Position.front
    //是否已经在录制
    var isRecording:Bool = false

    //@ScreenActor它的作用是为与屏幕相关的操作提供线程安全性和一致性。具体来说，它确保被标记的属性或方法在屏幕渲染上下文中执行（通常是主线程），避免因线程切换或并发访问导致的 UI 不一致或崩溃。 只会影响紧接其后的属性。如果你在两个属性之间插入空格或其他属性包装器，那么下一个属性将不受前一个包装器的影响
    @ScreenActor
    private var currentEffect: (any VideoEffect)?
    let front = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
    private(set) var streamMode2: TFStreamMode = .rtmp
    private var connection: Any?
    private(set) var stream: (any HKStream)?
    var isVideoMirrored:Bool = true
    let recorder = HKStreamRecorder()
    private lazy var mixer = MediaMixer()
    private lazy var audioCapture: AudioCapture = {
        let audioCapture = AudioCapture()
        audioCapture.delegate = self
        return audioCapture
    }()
    @ScreenActor
    private var videoScreenObject = VideoTrackScreenObject()
    
    var view2 = MTHKView(frame: .zero)
    /// Specifies the video size of encoding video.
     public var videoSize2:CGSize = CGSize(width: 0, height: 0 )
    /// Specifies the bitrate.
     var videoBitRate2: Int = 0
     var videoFrameRate2: CGFloat = 0
     var srtUrl:String = ""
    func setPreference()async {
        if streamMode2 == .srt {
            let connection = SRTConnection()
            self.connection = connection
            stream = SRTStream(connection: connection)
       
        } else {
            let connection = RTMPConnection()
            self.connection = connection
            stream = RTMPStream(connection: connection)
           
        }

    }
//    @objc public func setVideoGravity(_ videoGravity:AVLayerVideoGravity)
//    {
//        view2.videoGravity = videoGravity
//    }
    func configurationSDK(view:MTHKView,
                          videoSize:CGSize,
                          videoFrameRate:CGFloat,
                          videoBitRate:Int,
                          streamMode:TFStreamMode,
                          again:Bool)
    
    {
       
            view2 = view
            videoSize2 = videoSize
            videoBitRate2 = videoBitRate
            videoFrameRate2 = videoFrameRate
            streamMode2 = streamMode
            view2.videoGravity = .resizeAspectFill
     
        Task {  @ScreenActor in
            
            if again==false {
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
            }
     
           //配置推流类型
            await self.setPreference()
            //----------------
            guard let stream = self.stream else {
                return
            }
            await mixer.addOutput(stream)
            
            //配置录制
            await stream.addOutput(recorder)
            //配置视频预览容器
            await stream.addOutput(view)

            var videoSettings = await stream.videoSettings
            ///// 视频的码率，单位是 bps
            videoSettings.bitRate = videoBitRate
            ///// /// 视频的分辨率，宽高务必设定为 2 的倍数，否则解码播放时可能出现绿边(这个videoSizeRespectingAspectRatio设置为YES则可能会改变)
            videoSettings.videoSize = videoSize
            await stream.setVideoSettings(videoSettings)
                

        }
        if again==false {
            
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
                //设置默认是前置 然后设置镜像
                try? await mixer.attachVideo(front, track: 0){videoUnit in
                    videoUnit.isVideoMirrored = true
                }
            }
        }
        

    }
    @objc public func setSDK(view:MTHKView,
                             videoSize:CGSize,
                             videoFrameRate:CGFloat,
                             videoBitRate:Int,
                             streamMode:TFStreamMode)
    {

        self.configurationSDK(view: view,
                              videoSize: videoSize,
                              videoFrameRate: videoFrameRate,
                              videoBitRate: videoBitRate,
                              streamMode: streamMode,again:false)
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
    func closePush()
    {
        Task {  @ScreenActor in
            switch streamMode2 {
            case .rtmp:
                guard let connection = connection as? RTMPConnection else {
                    return
                }
                try? await connection.close()
                logger.info("conneciton.close")
            case .srt:
                guard let connection = connection as? SRTConnection else {
                    return
                }
                try? await connection.close()
                logger.info("conneciton.close")
            }
        }
    }
    /**结束推流**/
    @objc public func stopLive()
    {
        UIApplication.shared.isIdleTimerDisabled = true
        self.closePush()
    }
    /**开始推流**/
    @objc public func startLive(callback: ((Int, String) -> Void)?)
    {
        UIApplication.shared.isIdleTimerDisabled = false
        Task {  @ScreenActor in
            
            guard let stream = self.stream else {
                return
            }
          
                if streamMode2 == .rtmp {
                 
                    do {
                    guard
                        let connection = connection as? RTMPConnection,
                        let stream = stream as? RTMPStream else {
                        return
                    }
                    
                    let response3 = try await connection.connect(srtUrl)
                    logger.info(response3)
                        
                    let response2 = try await stream.publish("live")
                    logger.info(response2)
                        
                        
                            // 这里放需要在主线程中执行的代码
                         
                        
                                DispatchQueue.main.async {
                                    if let callback = callback {
                                        callback(0,"")
                                    }
                                }
                                
                            } catch RTMPConnection.Error.requestFailed(let response) {
                                logger.warn(response)
                                DispatchQueue.main.async {
                                    if let callback = callback {
                                        callback(-1,"")
                                    }
                                }
                                
                            } catch RTMPStream.Error.requestFailed(let response) {
                                logger.warn(response)
                                DispatchQueue.main.async {
                                    if let callback = callback {
                                        callback(-1,"")
                                    }
                                }
                                
                            } catch {
                                logger.warn(error)
                                DispatchQueue.main.async {
                                    if let callback = callback {
                                        callback(-1,"")
                                    }
                                }
                                
                            }
                   
              
                }else  if streamMode2 == .srt {
                    do {
                        guard let connection = connection as? SRTConnection, let stream = stream as? SRTStream else {
                            return
                        }
                        try await connection.open(URL(string: srtUrl))
                        //开始推流
                        await stream.publish()
                        logger.info("conneciton.open")
                        DispatchQueue.main.async {
                            if let callback = callback {
                                callback(0,"")
                            }
                        }
                    } catch {
                    
                        //打印错误原因
                        if let srtError = error as? SRTError {
                            
                            var msg:String = ""
                            switch srtError {
                                
                            case .illegalState(let message):
                                msg = message
        //                        print("Illegal state error: \(message)")
                                
                            case .invalidArgument(let message):
                                msg = message
        //                        print("Invalid argument error: \(message)")
                                
                                
                            }
                            DispatchQueue.main.async {
                                if let callback = callback {
                                    callback(-1,msg)
                                }
                                
                            }
                        }
                        
                    }
                   
                }
              
         
        }
    }
//    func urlEncode(_ string: String) -> String {
//        // 设置允许的字符集，这里允许的字符集是URL的保留字符和字母数字字符
//        let allowedCharacters = CharacterSet.alphanumerics.union(.punctuationCharacters).union(.whitespaces)
//        
//        // 如果转码成功返回编码后的字符串，否则返回空字符串
//        return string.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? ""
//    }

    /**
      配置推流URL
     */
    @objc public func setSrtUrl(url:String)
    {
        srtUrl = url

        /**
         Task {
            
             let streamMode = srtUrl.contains("srt://") ? TFStreamMode.srt : TFStreamMode.rtmp
             if(streamMode != streamMode2)
             {
                 
                 switch streamMode2 {
                 case .rtmp:
                     guard
                         let connection = connection as? RTMPConnection,
                         let stream = stream as? RTMPStream else {
                         return
                     }
                     try? await connection.close()
                     try? await stream.close()
                     self.connection = nil
                     self.stream = nil

                 case .srt:
                     guard let connection = connection as? SRTConnection, let stream = stream as? SRTStream else {
                         return
                     }
                     try? await connection.close()
                     try? await stream.close()
                     
                     self.connection = nil
                     self.stream = nil

                 }
                 
                 self.configurationSDK(view: view2,
                                       videoSize: videoSize2,
                                       videoFrameRate: videoFrameRate2,
                                       videoBitRate: videoBitRate2,
                                       streamMode: streamMode,
                                       again:true)
             }
          
         }
         */
           
      

     
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
    @objc public func switchCameraToType(cameraType:AVCaptureDevice.DeviceType,position: AVCaptureDevice.Position)->Bool
    {
        Task {  @ScreenActor in

                // .builtInWideAngleCamera
                let back = AVCaptureDevice.default(cameraType, for: .video, position:position)
                //track 是多个摄像头的下标
                try? await mixer.attachVideo(back, track: 0){ videoUnit in
                    
                    videoUnit.isVideoMirrored = false
                    
                   
                }

        }
        return true
    }
    /**静音**/
    @objc public func setMuted(_ muted:Bool)
    {
        Task {
            var audioMixerSettings = await mixer.audioMixerSettings
            audioMixerSettings.isMuted = muted
            await mixer.setAudioMixerSettings(audioMixerSettings)
        }
        
        
    }
    /**摄像头开关**/
    @objc public func setCamera(_ muted:Bool)
    
    {
        Task {
            if(muted)
            {
                 await mixer.startCapturing()
            }else{
                 await mixer.stopCapturing()
            }
        }
        
        
    }
    //重新配置视频
    @objc public func setVideoMixerSettings(_ videoSize:CGSize)
    
    {
        Task {
            guard let stream = self.stream else {
                return
            }
            var videoSettings = await stream.videoSettings
            
            ///// 视频的码率，单位是 bps
//            videoSettings.bitRate = videoBitRate
            ///// /// 视频的分辨率，宽高务必设定为 2 的倍数，否则解码播放时可能出现绿边(这个videoSizeRespectingAspectRatio设置为YES则可能会改变)
            videoSettings.videoSize = videoSize
            await stream.setVideoSettings(videoSettings)
            
        }
    }
    
    /**摄像头倍放**/
    @objc public func zoomScale(_ scale:CGFloat)
    {
        Task {
            try await mixer.configuration(video: 0) { unit in
                guard let device = unit.device else {
                    return
                }
                try device.lockForConfiguration()
                device.ramp(toVideoZoomFactor: scale, withRate: 5.0)
                device.unlockForConfiguration()
            }
        }
        
    }
    /**录制视频**/
    @objc public func recording(_ isRecording:Bool)
    {
        Task {  @ScreenActor in
            
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
    
    var effectsList: [TFFilter] = []
    /**水印*/
    @objc public func addWatermark(_ watermark:UIImage,frame:CGRect)
    {
        Task {
            
            for effect in effectsList {
                if effect.type == .watermark {
                    return
                }
            }
            //加有水印
            let effect = TFFilter()
            effect.type = .watermark
            effect.watermark = watermark
            effect.watermarkFrame = frame
            effectsList.append(effect)
            _ = await mixer.screen.registerVideoEffect(effect)
            
        }
    }
    /**清空水印*/
    @objc public func clearWatermark()
    
    {
        Task {
       
            var new_effectsList: [TFFilter] = []
            new_effectsList += effectsList
            
            for i in 0..<new_effectsList.count {
                let effect = new_effectsList[i]
                //清空所有滤层,留下水印
                if effect.type == .watermark {
                    effectsList.remove(at: i)
                    
                    _ = await mixer.screen.unregisterVideoEffect(effect)
                }
            }

        }
    }
    /**美颜开关*/
    @objc public var beauty: Bool = false {
        didSet {
            // 当 beauty 属性的值发生变化时执行的代码
            Task {  @ScreenActor in
                
                if(beauty==false)
                {
                    var new_effectsList: [TFFilter] = []
                    new_effectsList += effectsList
                
                    for i in 0..<new_effectsList.count {
                        let effect = new_effectsList[i]
                        //清空所有滤层,留下水印
                        if effect.type == .filters {
                            effectsList.remove(at: i)
                            _ = mixer.screen.unregisterVideoEffect(effect)
                        }
                       
                    }
                    
                }else{
                    var exist:Bool = false
                    for i in 0..<effectsList.count {
                        let effect = effectsList[i]
                        //清空所有滤层,留下水印
                        if effect.type == .filters {
                            exist = true
                        }
                       
                    }
                    
                    if exist==false {
                        //------------------
                          var watermark_list: [TFFilter] = []

                            for i in 0..<effectsList.count {
                                let effect = effectsList[i]
                                //清空所有滤层,留下水印

                                if effect.type == .watermark {
                                    
                                    effectsList.remove(at: i)
                                    watermark_list.append(effect)
                                    
                                    _ = mixer.screen.unregisterVideoEffect(effect)
                                }
                            }
                         //------------------
                            //美颜
                            let effect = TFFilter()
                            effect.type = .filters
                            effectsList.append(effect)
                            _ =  mixer.screen.registerVideoEffect(effect)
                        //------------------
                        //设置水印在最前面
                        if(watermark_list.count>0){
                            
                            for i in 0..<watermark_list.count {
                                let effect = watermark_list[i]
                                effectsList.append(effect)
                                _ = mixer.screen.registerVideoEffect(effect)
                          
                            }
                            
                        }
                    }
                   
                }
    
            }
            
            
        }
    }
    //设置焦点
    @objc public func setFocusBoxPoint(_ point: CGPoint, focusMode: AVCaptureDevice.FocusMode, exposureMode: AVCaptureDevice.ExposureMode) {
      
        if focusMode == .autoFocus && exposureMode == .autoExpose  {
            //.autoFocus 1 手动
          //.autoExpose 1 手动

                let size = view2.bounds.size
                let focusPoint = CGPoint(
                    x: CGFloat(point.y) / CGFloat(size.height),
                    y: 1.0 - (CGFloat(point.x) / CGFloat(size.width)))
                    
                self.setFocusBoxPointInternal(focusPoint, focusMode: focusMode, exposureMode: exposureMode)

        }
       
    }
    /**摄像头焦点设置**/
    private func setFocusBoxPointInternal(_ point: CGPoint, focusMode: AVCaptureDevice.FocusMode, exposureMode: AVCaptureDevice.ExposureMode) {
        
        Task {
            try await mixer.configuration(video: 0) { unit in
                guard let device = unit.device else {
                    return
                }
                self.focusPoint(point, focusMode: focusMode, exposureMode: exposureMode, device: device)
            }
        }
    }
     func focusPoint(_ focusPoint: CGPoint,
                              focusMode: AVCaptureDevice.FocusMode,
                              exposureMode: AVCaptureDevice.ExposureMode,
                              device: AVCaptureDevice?) {
           guard let device = device else { return }
           
           do {
               try device.lockForConfiguration()
               
               // 先进行判断是否支持控制对焦模式
               // 对焦模式和对焦点
               if device.isFocusModeSupported(focusMode) {
                   device.focusPointOfInterest = focusPoint
                   device.focusMode = focusMode
               }
               
               // 先进行判断是否支持曝光模式
               // 曝光模式和曝光点
               if device.isExposureModeSupported(exposureMode) {
                   device.exposurePointOfInterest = focusPoint
                   device.exposureMode = exposureMode
               }
               
               device.unlockForConfiguration()
           } catch {
               // 处理错误，例如打印或者显示错误信息
               print("Could not lock device for configuration: \(error)")
           }
       }
}
extension TFIngest: AudioCaptureDelegate {
    // MARK: AudioCaptureDelegate
    nonisolated func audioCapture(_ audioCapture: AudioCapture, buffer: AVAudioBuffer, time: AVAudioTime) {
        Task { await mixer.append(buffer, when: time) }
    }
}
