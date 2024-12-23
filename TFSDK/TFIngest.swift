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
import Combine

@objc public enum TFStreamMode: Int {
    case rtmp = 0
    case srt = 1
}
public class TFIngest: NSObject {
    //@ScreenActor它的作用是为与屏幕相关的操作提供线程安全性和一致性。具体来说，它确保被标记的属性或方法在屏幕渲染上下文中执行（通常是主线程），避免因线程切换或并发访问导致的 UI 不一致或崩溃。 只会影响紧接其后的属性。
    @ScreenActor
    private var videoScreenObject = VideoTrackScreenObject()
    //推流已经连接
    @objc public var isConnected:Bool = false
    
    //是否已经在录制
    var isRecording:Bool = false
    //录制视频保存的路径
    @objc public var saveLocalVideoPath:URL?
    
    var view2 = TFDisplays(frame: .zero)
    let front = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
    private(set) var streamMode2: TFStreamMode = .rtmp
    private var connection: Any?
    private(set) var stream: (any HKStream)?

    //镜像
     var mirror2:Bool = true
     let recorder = HKStreamRecorder()
     public var videoSize2:CGSize = CGSize(width: 0, height: 0 )
     public var videoBitRate2: Int = 0
     public var videoFrameRate2: CGFloat = 0

     private lazy var mixer = MediaMixer()
     private lazy var audioCapture: AudioCapture = {
        let audioCapture = AudioCapture()
        audioCapture.delegate = self
        return audioCapture
    }()
    private var myVideoMirrored:Bool = false

    //TODO: 根据配置初始化SDK-------------
    func configurationSDK(view:TFDisplays,
                          videoSize:CGSize,
                          videoFrameRate:CGFloat,
                          videoBitRate:Int,
                          streamMode:TFStreamMode,
                          mirror:Bool,
                          again:Bool)
    
    {
       
            view2 = view
            videoSize2 = videoSize
            videoBitRate2 = videoBitRate
        /// 最大关键帧间隔，可设定为 fps 的2倍，影响一个 gop 的大小
            videoFrameRate2 = videoFrameRate
            streamMode2 = streamMode
            view2.videoGravity = .resizeAspectFill
            mirror2 = mirror
        
        //again 是重新配置了url  @ScreenActor in
        Task {@ScreenActor in
            
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

            //-----------------------------------------------------------------
            
            try? await mixer.attachAudio(AVCaptureDevice.default(for: .audio))
            //设置默认是前置 然后设置镜像
            try? await mixer.attachVideo(front, track: 0){[weak self] videoUnit in
                guard let `self` = self else { return }
                self.setPosition(position: .front)
                videoUnit.isVideoMirrored = mirror
                self.myVideoMirrored = mirror
//                    //锁定前置是镜像
                  self.frontMirror(mirror)
    
            }
             //帧率
              await mixer.setFrameRate(videoFrameRate)
        }
        if again==false {
            
        Task { @ScreenActor in
             //screen 离屏渲染对象。
             mixer.screen.size = videoSize
             mixer.screen.backgroundColor = UIColor.black.cgColor
            videoScreenObject.cornerRadius = 16.0
            videoScreenObject.track = 1
            videoScreenObject.horizontalAlignment = .right
            videoScreenObject.layoutMargin = .init(top: 16, left: 0, bottom: 0, right: 16)
            videoScreenObject.size = .init(width: 160 * 2, height: 90 * 2)
            //本地显示的渲染配置
            try? mixer.screen.addChild(videoScreenObject)
            await mixer.startRunning()
           }
            
         

        }
    }
    //TODO: 视频的帧率，即 fps  @ScreenActor 线程的, 要等sdk初始化好才能调用
    @objc public func setFrameRate(_ videoFrameRate: Float64) {
        Task {
            await mixer.setFrameRate(videoFrameRate)
        }
    }
    @objc public func setSDK(view:TFDisplays,
                             videoSize:CGSize,
                             videoFrameRate:CGFloat,
                             videoBitRate:Int,
                             streamMode:TFStreamMode,
                             mirror:Bool)
    {

        self.configurationSDK(view: view,
                              videoSize: videoSize,
                              videoFrameRate: videoFrameRate,
                              videoBitRate: videoBitRate,
                              streamMode: streamMode,
                              mirror:mirror,
                              again:false)
        //TODO: 捕捉设备方向的变化
        NotificationCenter.default.addObserver(self, selector: #selector(on(_:)), name: UIDevice.orientationDidChangeNotification, object: nil)
        //TODO: 监听 AVAudioSession 的中断通知
        NotificationCenter.default.addObserver(self, selector: #selector(didInterruptionNotification(_:)), name: AVAudioSession.interruptionNotification, object: nil)
        //TODO: 用于捕捉音频路由变化（如耳机插入、蓝牙设备连接等）
        NotificationCenter.default.addObserver(self, selector: #selector(didRouteChangeNotification(_:)), name: AVAudioSession.routeChangeNotification, object: nil)
    }
    private var cancellable: AnyCancellable?

    func setPreference()async {
        if streamMode2 == .srt {
            let connection = SRTConnection()
            self.connection = connection
            stream = SRTStream(connection: connection)
            guard let stream = stream as? SRTStream else {
                return
            }
            Task {
                cancellable = await stream.$readyState.sink { newState in
                    switch newState {
                    case .idle:
                        print("srt流处于空闲状态。")
                    case .publishing:
                        print("srt流正在发布中")
                    case .playing:
                        print("srt流正在播放。")
                    case .play:
                        print("srt该流已发送播放请求，正在等待服务器批准。")
                    case .publish:
                        print("srt该流已发送发布请求并正在等待服务器的批准。")
                    }
                }
            }

        } else {
            let connection = RTMPConnection()
            self.connection = connection
            stream = RTMPStream(connection: connection)
            
            guard let stream = stream as? RTMPStream else {
                return
            }
            Task {
                cancellable = await stream.$readyState.sink { newState in
                    switch newState {
                    case .idle:
                        print("rtmp流处于空闲状态。")
                    case .publishing:
                        print("rtmp流正在发布中")
                    case .playing:
                        print("rtmp流正在播放。")
                    case .play:
                        print("rtmp该流已发送播放请求，正在等待服务器批准。")
                    case .publish:
                        print("rtmp该流已发送发布请求并正在等待服务器的批准。")
                    }
                }
            }
        }

    }
    //TODO: 捕捉设备方向的变化
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
    //TODO: 监听 AVAudioSession 的中断通知
    @objc
    private func didInterruptionNotification(_ notification: Notification) {
        logger.info(notification)
    }
    //TODO: 用于捕捉音频路由变化（如耳机插入、蓝牙设备连接等）
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
        Task {
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
    //TODO: 结束推流
    @objc public func stopLive()
    {
        if self.isConnected {
            UIApplication.shared.isIdleTimerDisabled = true
            self.closePush()
        }
   
    }
    //TODO: 开始推流
    @objc public func startLive(url:String,callback: ((Int, String) -> Void)?)
    {
        UIApplication.shared.isIdleTimerDisabled = false
        Task {
            
            guard let stream = self.stream else {
                return
            }
          
                if streamMode2 == .rtmp {
                    self.isConnected = false
                    
                    do {
                    guard
                        let connection = connection as? RTMPConnection,
                        let stream = stream as? RTMPStream else {
                        return
                    }
                    
                    let response3 = try await connection.connect(url)

                    let response2 = try await stream.publish("live")

                        self.isConnected = true
                        self.callback(callback,code:0,msg: "")
                        
                        
                            } catch RTMPConnection.Error.requestFailed(let response) {
                                logger.warn(response)
                                self.callback(callback,code: -1,msg: "")
                                
                            } catch RTMPStream.Error.requestFailed(let response) {
                                logger.warn(response)
                                self.callback(callback,code: -1,msg: "")
                                
                            } catch {
                                logger.warn(error)
                               
                                self.callback(callback,code: -1,msg: "")
                            }
                   
              
                }
            else  if streamMode2 == .srt {
                self.isConnected = false
                    do {
                        guard let connection = connection as? SRTConnection, let stream = stream as? SRTStream else {
                            return
                        }
                        try await connection.open(URL(string: url))
                        //开始推流
                        await stream.publish()
                        self.isConnected = true
                        self.callback(callback,code: 0,msg: "")
                    } catch {
                    
                        //打印错误原因
                        if let srtError = error as? SRTError {
                            
                            var msg:String = ""
                            switch srtError {
                                
                            case .illegalState(let message):
                                msg = message

                            case .invalidArgument(let message):
                                msg = message
                    
                            }
                            self.callback(callback,code: -1,msg: msg)
                        }
                        
                    }
                   
                }
              
         
        }
    }
    //TODO: 切换推流类型
    @objc public func renew(streamMode:TFStreamMode)
    {
     
         Task {
             if( streamMode2 != streamMode)
             {
                    streamMode2 = streamMode
                  
                     switch streamMode2 {
                     case .rtmp:
                         
                        if let connection = connection as? SRTConnection, let stream = stream as? SRTStream
                         {
                            try? await connection.close()
                           
                            
                            self.connection = nil
                            self.stream = nil
                        }
                   
                     case .srt:
                    
                        if let connection = connection as? RTMPConnection,
                           let stream = stream as? RTMPStream
                         {
                            try? await connection.close()
                           
                            self.connection = nil
                            self.stream = nil
                        }
                         
                     }
                     
                     
                     self.configurationSDK(view: view2,
                                           videoSize: videoSize2,
                                           videoFrameRate: videoFrameRate2,
                                           videoBitRate: videoBitRate2,
                                           streamMode: streamMode,
                                           mirror:self.mirror2,
                                           again:true)
                     
                 
                
                 
               
                 
             }
             
         }
      
    }
    func callback(_ callback: ((Int, String) -> Void)?,code:NSInteger,msg:String)
    {
        DispatchQueue.main.async {
            if let callback = callback {
                callback(code,msg)
            }
            
        }
    }

    //TODO: 前置or后置 摄像头
    @objc public func attachVideo(position: AVCaptureDevice.Position)
    {
        Task {
            
        try? await mixer.attachVideo(AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)) {[weak self] videoUnit in
            guard let `self` = self else { return }
            self.setPosition(position: position)
            if(position == .front)
            {
                videoUnit.isVideoMirrored = self.myVideoMirrored
            }else{
                videoUnit.isVideoMirrored = false
            }
            
         }
       }
    }
    func setPosition(position: AVCaptureDevice.Position)
    {
        DispatchQueue.main.async {

            // 在闭包中使用 position，而不是捕获 self
            self.view2.position = position
        }
    }
//    let mirror_effect = MirrorEffect()
    //TODO:  前置摄像头的本地预览锁定为水平翻转  默认 true
    @objc public var frontCameraPreviewLockedToFlipHorizontally: Bool = true {
        didSet {
            //锁定前置是镜像
            self.frontMirror(myVideoMirrored)
        }
    }
    func frontMirror(_ mirrored:Bool)
    {

        if self.view2.position == .front && mirrored == false && self.frontCameraPreviewLockedToFlipHorizontally {

//                // 在预览视图上直接应用变换
                self.view2.isMirrorDisplay = true
//
            }else
            {
                self.view2.isMirrorDisplay = false
        }
    }
    //TODO: 镜像 开关
    @objc public func configuration(isVideoMirrored:Bool) {
        
        if self.view2.position == .front
            {  //前置
                Task {
                    try await mixer.configuration(video: 0) { [weak self] unit in
                        guard let `self` = self else { return }
                        unit.isVideoMirrored = isVideoMirrored
                        self.myVideoMirrored = isVideoMirrored
                        //锁定前置是镜像
                        self.frontMirror(isVideoMirrored)
                        
                    }
                }
                
            }

        
    }
    //TODO: 设置 近  中 远 摄像头
    @objc public func switchCameraToType(cameraType:AVCaptureDevice.DeviceType,position: AVCaptureDevice.Position)->Bool
    {
        Task {

                // .builtInWideAngleCamera
                let back = AVCaptureDevice.default(cameraType, for: .video, position:position)
                //track 是多个摄像头的下标
                try? await mixer.attachVideo(back, track: 0){[weak self] videoUnit in
                    guard let `self` = self else { return }
                    if position == .front
                    {
                        videoUnit.isVideoMirrored = self.myVideoMirrored
                    }else
                    {
                        videoUnit.isVideoMirrored = false
                    }
                }

        }
        return true
    }
    //TODO: 静音
    @objc public func setMuted(_ muted:Bool)
    {
        Task {
            var audioMixerSettings = await mixer.audioMixerSettings
            audioMixerSettings.isMuted = muted
            await mixer.setAudioMixerSettings(audioMixerSettings)
        }
   
    }
    //TODO:  摄像头开关
    @objc public func setCamera(_ muted:Bool)
    {
        Task {
            if(muted)
            {
//                await mixer.startCapturing()
                try await mixer.attachVideo(AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: self.view2.position))

            }else{
//                 await mixer.stopCapturing()
                try? await mixer.attachVideo(nil, track: 0)
            }
        }
    }
    //TODO: 重新配置视频
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
    //TODO: 摄像头倍放
    @objc public func zoomScale(_ scale:CGFloat)
    {
        Task {
            //[weak self]
            try await mixer.configuration(video: 0) { unit in
//                guard let `self` = self else { return }
                guard let device = unit.device else {
                    return
                }
                try device.lockForConfiguration()
                device.ramp(toVideoZoomFactor: scale, withRate: 5.0)
                device.unlockForConfiguration()
            }
        }
        
    }
    //TODO: 录制视频 开关
    @objc public func recording(_ isRecording:Bool)
    {
        Task {
            
          
            if isRecording {
                

                if self.isRecording == false {
                    
                    if let saveLocalVideoPath = saveLocalVideoPath
                    {
                        print("srt录制的视频存放地址为=======>",saveLocalVideoPath)
                        //                AVSampleRateKey = 44.1KHz 采样率,
                        /// AVNumberOfChannelsKey 声道数目(default 2)
                        try await recorder.startRecording(saveLocalVideoPath, settings: [
                            AVMediaType.audio: [
                                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                                AVSampleRateKey: 44100,
                                AVNumberOfChannelsKey: 2,
                            ],
                            AVMediaType.video: [
                                AVVideoCodecKey: AVVideoCodecType.h264,
                                AVVideoHeightKey: 0,
                                AVVideoWidthKey: 0,
                                
                            ]
                        ])
                        
                    }
                    
                }
                
                
            }else{
                
                
                if self.isRecording {
                    do {
                        let recordingURL = try await recorder.stopRecording()
                        // 处理录制文件的 URL
                        print("srt保存录制视频成功: \(recordingURL)")
                    } catch {
                        
                        print("srt保存录制视频失败: \(error)")
                    }
                }
             
            }
            
            self.isRecording = isRecording
            
        }
        
    }
    
    //-----------------------------------------------
    
    var effectsList: [TFFilter] = []
    //TODO: 添加水印
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
    //TODO: 清空水印
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
    //TODO: 美颜开关
    @objc public var beauty: Bool = false {
        didSet {
            // 当 beauty 属性的值发生变化时执行的代码
            Task {
                
                if(beauty==false)
                {
                    var new_effectsList: [TFFilter] = []
                    new_effectsList += effectsList
                
                    for i in 0..<new_effectsList.count {
                        let effect = new_effectsList[i]
                        //清空所有滤层,留下水印
                        if effect.type == .filters {
                            effectsList.remove(at: i)
                            _ = await mixer.screen.unregisterVideoEffect(effect)
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
                                    
                                    _ = await mixer.screen.unregisterVideoEffect(effect)
                                }
                            }
                         //------------------
                            //美颜
                            let effect = TFFilter()
                            effect.type = .filters
                            effectsList.append(effect)
                            _ =  await mixer.screen.registerVideoEffect(effect)
                        //------------------
                        //设置水印在最前面
                        if(watermark_list.count>0){
                            
                            for i in 0..<watermark_list.count {
                                let effect = watermark_list[i]
                                effectsList.append(effect)
                                _ = await mixer.screen.registerVideoEffect(effect)
                          
                            }
                            
                        }
                    }
                   
                }
    
            }
            
            
        }
    }
    //TODO: 设置焦点
    @objc public func setFocusBoxPoint(_ point: CGPoint, focusMode: AVCaptureDevice.FocusMode, exposureMode: AVCaptureDevice.ExposureMode) {
      
        if focusMode == .autoFocus && exposureMode == .autoExpose  {
            //.autoFocus 1 手动
          //.autoExpose 1 手动
          self.setFocusBoxPointInternal(point, focusMode: focusMode, exposureMode: exposureMode)

        }
       
    }
    /**摄像头焦点设置**/
    private func setFocusBoxPointInternal(_ point: CGPoint, focusMode: AVCaptureDevice.FocusMode, exposureMode: AVCaptureDevice.ExposureMode) {
        
        Task {
            try await mixer.configuration(video: 0) {[weak self] unit in
                guard let `self` = self else { return }
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
    // MARK: - 视频的时间戳数据
    @objc public func sendData(_ text: String)
    {
//        NSString *time = [NSString stringWithFormat:@"disposeTime:%0.1f",self.disposeTime] ;
        
    }
    //TODO:  推送自定义图像
    @objc public func pushVideo(_ pixelBuffer: CVPixelBuffer) {
        // 1. 检查 stream 是否存在，避免进入 Task 后再检查
        guard let stream = self.stream else {
            print("Stream not available")
            return
        }
        
        Task {
            do {
                // 2. 使用结构化的错误处理
                let buffer = try await createSampleBuffer(from: pixelBuffer)
                await stream.append(buffer)
            } catch {
                print("Failed to push video: \(error)")
            }
        }
    }

    // 3. 将 SampleBuffer 创建逻辑分离到独立函数
    private func createSampleBuffer(from pixelBuffer: CVPixelBuffer) async throws -> CMSampleBuffer {
        // 4. 使用精确的时间戳计算
        let timestamp = CACurrentMediaTime()
        var timingInfo = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 30),
            presentationTimeStamp: CMTime(seconds: timestamp, preferredTimescale: 30),
            decodeTimeStamp: .invalid
        )
        
        // 5. 创建 video format description
        var videoInfo: CMFormatDescription?
        let formatStatus = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &videoInfo
        )
        
        guard formatStatus == noErr, let videoInfo = videoInfo else {
            throw NSError(domain: "VideoProcessing", code: Int(formatStatus))
        }
        
        // 6. 创建 sample buffer
        var sampleBuffer: CMSampleBuffer?
        let createStatus = CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: videoInfo,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sampleBuffer
        )
        
        guard createStatus == noErr, let buffer = sampleBuffer else {
            throw NSError(domain: "VideoProcessing", code: Int(createStatus))
        }
        
        return buffer
    }

    // 7. 添加自定义错误类型
    enum VideoProcessingError: Error {
        case streamNotAvailable
        case formatDescriptionCreationFailed
        case sampleBufferCreationFailed
    }

    // 8. 可选：添加性能监控
    private var lastFrameTime: CFTimeInterval = 0
    private func logFrameRate() {
        let currentTime = CACurrentMediaTime()
        let elapsed = currentTime - lastFrameTime
        lastFrameTime = currentTime
        
        #if DEBUG
        print("Frame interval: \(elapsed * 1000)ms (~ \(1.0 / elapsed) fps)")
        #endif
    }
    //TODO: 关闭SDK
    @objc public func shutdown()
    {
        Task { @ScreenActor in
    
            self.recording(false)

            //结束推流
            self.closePush()
            await mixer.stopRunning()
            try? await mixer.attachAudio(nil)
            try? await mixer.attachVideo(nil, track: 0)
            try? await mixer.attachVideo(nil, track: 1)
            
        }
        NotificationCenter.default.removeObserver(self)
    }
}
extension TFIngest: AudioCaptureDelegate {
    // MARK: AudioCaptureDelegate
    nonisolated func audioCapture(_ audioCapture: AudioCapture, buffer: AVAudioBuffer, time: AVAudioTime) {
        Task { await mixer.append(buffer, when: time) }
    }
    

}
