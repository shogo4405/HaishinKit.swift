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

public class TFIngest: NSObject {
    //是否已经在录制
    var isRecording:Bool = false
    //录制视频保存的路径
    @objc public var saveLocalVideoPath:URL?
    //预览视频
    var preview = TFDisplays(frame: .zero)
    let recorder = HKStreamRecorder()
    
     private var mixer:MediaMixer? = nil
     private var myVideoMirrored:Bool = false
    
    var pushUrl:String = ""
    @objc public let preference = TFStreamPreference()
    
    //美颜
    let beauty_effect = TFTFBeautyFilter()
    //水印
    let watermark_effect = TFWatermarkFilter()
    //裁剪
    let cropRectFilter = TFCropRectFilter()
    //格挡
    let cameraPicture = TFCameraPictureFilter()
    
    @objc public let configuration = TFIngestConfiguration()
    //TODO: 根据配置初始化SDK-------------
    @objc public func setSDK(preview:TFDisplays,
                             videoSize:CGSize,
                             videoFrameRate:CGFloat,
                             videoBitRate:Int,
                             streamMode:TFStreamMode,
                             mirror:Bool,
                             cameraType:AVCaptureDevice.DeviceType,
                             position: AVCaptureDevice.Position,
                             outputImageOrientation:AVCaptureVideoOrientation)
    {
        self.configurationSDK(preview: preview,
                              videoSize: videoSize,
                              videoFrameRate: videoFrameRate,
                              videoBitRate: videoBitRate,
                              streamMode: streamMode,
                              mirror:mirror,
                              cameraType:cameraType,
                              position:position,
                              again:false,
                              startLive:false,
                              outputImageOrientation:outputImageOrientation)
        //TODO: 捕捉设备方向的变化
//        NotificationCenter.default.addObserver(self, selector: #selector(on(_:)), name: UIDevice.orientationDidChangeNotification, object: nil)
        //TODO: 监听 AVAudioSession 的中断通知
        NotificationCenter.default.addObserver(self, selector: #selector(didInterruptionNotification(_:)), name: AVAudioSession.interruptionNotification, object: nil)
        //TODO: 用于捕捉音频路由变化（如耳机插入、蓝牙设备连接等）
        NotificationCenter.default.addObserver(self, selector: #selector(didRouteChangeNotification(_:)), name: AVAudioSession.routeChangeNotification, object: nil)
    }
    func configurationSDK(preview:TFDisplays,
                          videoSize:CGSize,
                          videoFrameRate:CGFloat,
                          videoBitRate:Int,
                          streamMode:TFStreamMode,
                          mirror:Bool,
                      cameraType:AVCaptureDevice.DeviceType,
                          position:AVCaptureDevice.Position,
                          again:Bool,
                          startLive:Bool,
                          outputImageOrientation: AVCaptureVideoOrientation,
                          callback: ((_ code: Int, _ msg: String) -> Void)? = nil)
    {
              self.preview = preview
         configuration.streamMode = streamMode
            preference.streamMode = streamMode
            preview.videoGravity = .resizeAspectFill
            configuration.mirror = mirror
        configuration.currentDeviceType = cameraType
        configuration.currentPosition = position
            configuration.videoBitRate = videoBitRate
            configuration.videoFrameRate = videoFrameRate
            configuration.mirror = mirror
            configuration.outputImageOrientation = outputImageOrientation
        
        if self.mixer == nil {
            mixer = MediaMixer()
            
            Task {
                
                guard let mixer = self.mixer else {
                    return
                }
                
    
                //裁剪
                cropRectFilter.isAvailable = true
                cropRectFilter.videoSize = videoSize
                _ = await mixer.screen.registerVideoEffect(cropRectFilter)
                //美颜
                _ =  await mixer.screen.registerVideoEffect(beauty_effect)
                //水印
                _ = await mixer.screen.registerVideoEffect(watermark_effect)
                //格挡
                _ = await mixer.screen.registerVideoEffect(cameraPicture)
                
                
            }
        }
        //again 是重新配置了url
        Task {@ScreenActor in
            
            guard let mixer = self.mixer else {
                return
            }
            if again==false {

                await mixer.setVideoOrientation(outputImageOrientation)

                await mixer.setMonitoringEnabled(DeviceUtil.isHeadphoneConnected())
                
                var videoMixerSettings = await mixer.videoMixerSettings
                videoMixerSettings.mode = .offscreen
                await mixer.setVideoMixerSettings(videoMixerSettings)
                
                //screen 离屏渲染对象。
                mixer.screen.size = videoSize
                mixer.screen.backgroundColor = UIColor.black.cgColor
            }
            
            //----------------
            guard let stream = self.preference.stream() else {
                return
            }
            await mixer.addOutput(stream)
            //配置录制
            await stream.addOutput(self.recorder)
            //配置视频预览容器
            await stream.addOutput(preview)

            var videoSettings = await stream.videoSettings
            ///// 视频的码率，单位是 bps
            videoSettings.bitRate = videoBitRate
            ///// /// 视频的分辨率，宽高务必设定为 2 的倍数，
            videoSettings.videoSize = videoSize
            await stream.setVideoSettings(videoSettings)
            //视频的帧率
             await mixer.setFrameRate(videoFrameRate)

            await self.setAllVideoSize(videoSize: videoSize)
            
            //切换了推流类型
            if(startLive && self.pushUrl.count>0)
            {
                print("切换了推流类型,重新开始推流")
                    self.startLive(url: self.pushUrl) {[weak self] code, msg in
                        guard let `self` = self else { return }
                        
                        self.preference.statusChanged(status: self.preference.push_status)
                        if callback != nil {
                            
                            callback!(code, msg)
                            
                        }
                    }
                    
              
            }else{
                self.preference.pause = false
                if callback != nil {
                    callback!(0, "")
                }
            }

        }
        if again==false {
            
            Task {
               
                guard let mixer = self.mixer else {
                    return
                }
 
                  _ = try? await mixer.attachAudio(AVCaptureDevice.default(for: .audio))
                    
                    if(self.isCamera)
                    {
                        let device = AVCaptureDevice.default(cameraType, for: .video, position:position)
                        
                        //track 是多个摄像头的下标
                        try? await mixer.attachVideo(device, track: 0){[weak self] videoUnit in
                            guard let `self` = self else { return }
                            videoUnit.isVideoMirrored = mirror
                            self.myVideoMirrored = mirror
                            
                            //记住  前摄像 or 后摄像头
                            self.setPosition(position: position)
                            //酵预览 镜像显示控制属性
                            self.frontMirror(mirror)
                            
//                            //倍放
                            guard let device = videoUnit.device else {
                                return
                            }
                            try device.lockForConfiguration()
                            device.ramp(toVideoZoomFactor: self.zoom, withRate: 5.0)
                            device.unlockForConfiguration()
                            
                        }
                    }
               
     
            }
        }

    }
    //TODO: 视频的帧率，即 fps
    @objc public func setFrameRate(_ videoFrameRate: Float64) {
        Task {
            guard let mixer = self.mixer else {
                return
            }
            await mixer.setFrameRate(videoFrameRate)
        }
    }

    private var cancellable: AnyCancellable?

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
            guard let mixer = self.mixer else {
                return
            }
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

        if AVAudioSession.sharedInstance().inputDataSources?.isEmpty == true {
            TFIngestTool.setEnabledPreferredInputBuiltInMic(false)

        } else {
            TFIngestTool.setEnabledPreferredInputBuiltInMic(true)

        }

        Task {
            guard let mixer = self.mixer else {
                return
            }
            if DeviceUtil.isHeadphoneDisconnected(notification) {
                await mixer.setMonitoringEnabled(false)
            } else {
                await mixer.setMonitoringEnabled(DeviceUtil.isHeadphoneConnected())
            }
        }
    }
    
    //TODO: 结束推流
    @objc public func stopLive()
    {
        if self.preference.isConnected {
            DispatchQueue.main.async {
                UIApplication.shared.isIdleTimerDisabled = true
            }
            preference.close()
        }
   
    }
    //TODO: 开始推流
    @objc public func startLive(url:String,callback: ((Int, String) -> Void)?)
    {
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        self.pushUrl = url
        Task {
            
            if configuration.streamMode == .rtmp {
                  
                    do {
                    guard
                      
                        let stream = preference.stream() as? RTMPStream else {
                        return
                    }
                    let connection = preference.rtmpConnection
                        
                    let connect_response3 = try await connection.connect(url)
                    logger.info(connect_response3)
                    let publish_response = try await stream.publish(TFIngestTool.extractLastPathComponent(from: url))
                    logger.info(publish_response)
                        
                       
                        self.startLiveCallback(callback,code:0,msg: "")
                        
                        
                            } catch RTMPConnection.Error.requestFailed(let response) {
                                logger.warn(response)
                                self.startLiveCallback(callback,code: -1,msg: "")
                                
                            } catch RTMPStream.Error.requestFailed(let response) {
                                logger.warn(response)
                                self.startLiveCallback(callback,code: -1,msg: "")
                                
                            } catch {
                                logger.warn(error)
                               
                                self.startLiveCallback(callback,code: -1,msg: "")
                            }
                   
              
                }
            else  if configuration.streamMode == .srt {
              
                    do {
                        guard let stream = preference.stream() as? SRTStream else {
                            return
                        }
                        let connection = preference.srtConnection
                        
                        try await connection.open(URL(string: url))
                    
                        await stream.publish()

                        self.startLiveCallback(callback,code: 0,msg: "")
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
                            self.startLiveCallback(callback,code: -1,msg: msg)
                        }
                        
                    }
                   
                }
              
         
        }
    }
    //TODO: 切换推流类型
    @objc public func renew(streamMode: TFStreamMode,
                            pushUrl: String,
                            startLive:Bool,
                            callback: @escaping (_ code: Int, _ msg: String) -> Void)

    {
        self.pushUrl = pushUrl
         Task {
             guard let mixer = self.mixer else {
                 return
             }
             if streamMode != configuration.streamMode
             {
                
                 configuration.streamMode = streamMode
                 preference.streamMode = streamMode
                 //暂时暂停回调直播状态
                 preference.pause = true
                
    
                 _ = try? await self.preference.rtmpConnection.close()
                 if let rtmpStream = preference.rtmpStream
                 {
                     _ = try? await rtmpStream.close()
                     await mixer.removeOutput(rtmpStream)
                 }
                 //-------------
                 _ = try? await preference.srtConnection.close()
                  if let srtStream = preference.srtStream
                  {
                      await srtStream.close()
                      await mixer.removeOutput(srtStream)
                  }
                 
                 self.preference.isConnected = startLive
                 let startTime = DispatchTime.now()
                 self.configurationSDK(preview: preview,
                                       videoSize: configuration.videoSize,
                                       videoFrameRate: configuration.videoFrameRate,
                                       videoBitRate: configuration.videoBitRate,
                                       streamMode: streamMode,
                                       mirror:configuration.mirror,
                                       cameraType: configuration.currentDeviceType,
                                       position: configuration.currentPosition,
                                       again:true,
                                       startLive:startLive,
                                       outputImageOrientation:configuration.outputImageOrientation) { code, msg in
                         let elapsedTime = DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds
                         let elapsedSeconds = Double(elapsedTime) / 1_000_000_000.0
                         let delay = max(0.5 - elapsedSeconds, 0)
                         
                         DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                             callback(code, msg)
                         }
                     
                 }
                 
             }else{
                 
                 DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                     callback(0, "")
                 }
                 
                 
             }
        
         }
      
    }
    //TODO: 前置or后置 摄像头
    @objc public func attachVideo(position: AVCaptureDevice.Position)
    {
       
        Task {
            guard let mixer = self.mixer else {
                return
            }
            if (isCamera)
            {
                let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position:position)
                
                try? await mixer.attachVideo(device, track: 0){[weak self] videoUnit in
                    guard let `self` = self else { return }

                    configuration.currentPosition = position
                self.setPosition(position: position)
                if(position == .front)
                {
                    videoUnit.isVideoMirrored = self.myVideoMirrored
                }else{
                    videoUnit.isVideoMirrored = false
                }
                
             }
            }else
            {
                configuration.currentPosition = position
            }
       
       }
    }
    //TODO: 设置前置与后置 的 近中 远 摄像头
    @objc public func switchCameraToType(cameraType:AVCaptureDevice.DeviceType,position: AVCaptureDevice.Position)->Bool
    {
        Task {
            guard let mixer = self.mixer else {
                return
            }
            if (isCamera)
            {
                let device = AVCaptureDevice.default(cameraType, for: .video, position:position)

                //track 是多个摄像头的下标
                try? await mixer.attachVideo(device, track: 0){[weak self] videoUnit in
                    guard let `self` = self else { return }
                    
                    configuration.currentDeviceType = cameraType
                    configuration.currentPosition = position
                    
                    self.setPosition(position: position)
                    
                    if position == .front
                    {
                        videoUnit.isVideoMirrored = self.myVideoMirrored
                    }else
                    {
                        videoUnit.isVideoMirrored = false
                    }
                }
            }else
            {
                
                configuration.currentDeviceType = cameraType
                configuration.currentPosition = position
                
            }
           
        }
        return true
    }
    ////记住  前摄像 or 后摄像头
    func setPosition(position: AVCaptureDevice.Position)
    {
        DispatchQueue.main.async {
            self.preview.position = position
        }
    }

    //TODO:  前置摄像头的本地预览锁定为水平翻转  默认 true
    @objc public var frontCameraPreviewLockedToFlipHorizontally: Bool = true {
        didSet {
            //锁定前置是镜像
            self.frontMirror(myVideoMirrored)
        }
    }
    func frontMirror(_ mirrored:Bool)
    {
        if self.preview.position == .front && mirrored == false && self.frontCameraPreviewLockedToFlipHorizontally {

            // 在预览视图上直接应用变换
            self.preview.isMirrorDisplay = true

            }else
            {
                self.preview.isMirrorDisplay = false
            }
    }
    //TODO: 镜像 开关
    @objc public func configuration(isVideoMirrored:Bool) {
        
        if self.preview.position == .front
            {
            guard let mixer = self.mixer else {
                return
            }
            if (isCamera)
            {
                //前置
                    Task {
                        try await mixer.configuration(video: 0) { [weak self] unit in
                            guard let `self` = self else { return }
                            unit.isVideoMirrored = isVideoMirrored
                            self.myVideoMirrored = isVideoMirrored
                            //锁定前置是镜像
                            self.frontMirror(isVideoMirrored)
                            
                            //倍放
                            guard let device = unit.device else {
                                return
                            }
                            try device.lockForConfiguration()
                            device.ramp(toVideoZoomFactor:self.zoom, withRate: 5.0)
                            device.unlockForConfiguration()
                            
                        }
                    }
            }
            
                
            }

    }
    //TODO: 静音
    @objc public func setMuted(_ muted:Bool)
    {
        Task {
            guard let mixer = self.mixer else {
                return
            }
            var audioMixerSettings = await mixer.audioMixerSettings
            audioMixerSettings.isMuted = muted
            await mixer.setAudioMixerSettings(audioMixerSettings)
        }
   
    }
    //默认的摄像头是打开的
    var isCamera:Bool = true;
    //TODO:  摄像头开关
    @objc public func setCamera(_ camera:Bool)
    {

        Task {@ScreenActor in
           
            //先加上格挡
    
            if(camera)
            {
                guard let mixer = self.mixer else {
                    return
                }
                cameraPicture.isAvailable = false
                cameraPicture.imageBlock = nil
                let device = AVCaptureDevice.default(configuration.currentDeviceType, for: .video, position:configuration.currentPosition)
                try? await mixer.attachVideo(device, track: 0){ videoUnit in }
                    
               
        
            }else{
                cameraPicture.isAvailable = true
                
                cameraPicture.imageBlock = {[weak self] in
                    guard let `self` = self else { return }
                    guard let mixer = self.mixer else {
                        return
                    }
                    Task {@ScreenActor in
                        try? await mixer.attachVideo(nil, track: 0)
                        
                    }
                    
                }
      
            }
            isCamera = camera
        }
    }

    func setAllVideoSize(videoSize:CGSize) async
    {
        guard let stream = self.preference.stream() else {
            return
        }
        var videoSettings = await stream.videoSettings
        videoSettings.videoSize = videoSize
        //当前
        configuration.videoSize = videoSize
        //水印
        watermark_effect.videoSize = videoSize
        //裁剪
        cropRectFilter.videoSize = videoSize
        //格挡
        cameraPicture.videoSize = videoSize
    }
    //TODO: 重新配置视频分辨率
    @objc public func setVideoMixerSettings(videoSize:CGSize,
                                            videoFrameRate:CGFloat,
                                            videoBitRate:Int)
    
    {
        Task {
            guard let mixer = self.mixer else {
                return
            }
            guard let stream = self.preference.stream() else {
                return
            }
            var videoSettings = await stream.videoSettings
            ///// 视频的码率，单位是 bps
            videoSettings.bitRate = videoBitRate
            ///// /// 视频的分辨率，宽高务必设定为 2 的倍数
            videoSettings.videoSize = videoSize
            await stream.setVideoSettings(videoSettings)
            //-----------------------------------------------------------------
            configuration.videoFrameRate = videoFrameRate
            configuration.videoBitRate = videoBitRate
            await self.setAllVideoSize(videoSize: videoSize)
            //视频的帧率
            await mixer.setFrameRate(videoFrameRate)
          
            try await mixer.configuration(video: 0) {[weak self] unit in
                guard let `self` = self else { return }

                if((unit.device) != nil)
                {
                    //真正的变分辨率 
                    self.screenVideoSize(videoSize: videoSize)
                }
               
            }
        }
    }
    func screenVideoSize(videoSize:CGSize)
    {
        guard let mixer = self.mixer else {
            return
        }
        Task {@ScreenActor in
            mixer.screen.size = videoSize
        }
    }
    //默认倍放
    var zoom:CGFloat = 1.0
    //TODO: 摄像头倍放
    @objc public func zoomScale(_ scale:CGFloat)
    {
        Task {
            guard let mixer = self.mixer else {
                return
            }
            if(isCamera)
            {
                try await mixer.configuration(video: 0) { unit in
                    guard let device = unit.device else {
                        return
                    }
                    try device.lockForConfiguration()
                    device.ramp(toVideoZoomFactor: scale, withRate: 5.0)
                    device.unlockForConfiguration()
                }
            }else
            {
                
                zoom = scale
                
            }
          
        }
        
    }
    // 1. 首先定义回调的类型
    public typealias RecordingCompletionHandler = (_ success: Bool, _ url: URL?, _ error: Error?) -> Void

    func getvideoPath()->URL?
    {
        var videoPath:URL?
         if let saveLocalVideoPath = saveLocalVideoPath {
             videoPath = saveLocalVideoPath
         }
        
        return videoPath
    }
    //TODO: 录制视频 开关
    @objc public func recording(_ isRecording: Bool, completion: RecordingCompletionHandler? = nil) {
        Task {
            if isRecording {
                if self.isRecording == false {
                    
                    do {
                        try await recorder.startRecording(self.getvideoPath(), settings: [
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
                        // 开始录制成功回调
                        await MainActor.run {
                            completion?(true, self.getvideoPath(), nil)
                        }
                    } catch {
                        // 开始录制失败回调
                        await MainActor.run {
                            completion?(false, nil, error)
                        }
                    
                        
                    }
                    
                }
                
            } else {
                if self.isRecording {
                    do {
                        let recordingURL = try await recorder.stopRecording()
                        // 停止录制成功回调
                        await MainActor.run {
                            completion?(true, recordingURL, nil)
                        }
                    } catch {
                        // 停止录制失败回调
                        await MainActor.run {
                            completion?(false, nil, error)
                            self.isRecording = true
                        }
                    }
                }
            }
            
            self.isRecording = isRecording
        }
    }
    var effectsList: [TFFilter] = []
    //TODO: 添加水印
    @objc public func addWatermark(_ image:UIImage,frame:CGRect)
    {
       
          //启动
            watermark_effect.isAvailable = true
            
            watermark_effect.watermarkFrame = frame
            watermark_effect.watermark = image
            
        
    }
    //TODO: 清空水印
    @objc public func clearWatermark()
    {
            watermark_effect.isAvailable = false
    }
    //TODO: 美颜开关
    @objc public var beauty: Bool = false {
        didSet {
           
            beauty_effect.isAvailable = beauty
            
        }
    }
    //TODO: 设置焦点
    @objc public func setFocusBoxPoint(_ point: CGPoint,
                                       focusMode: AVCaptureDevice.FocusMode,
                                       exposureMode: AVCaptureDevice.ExposureMode) {
      
        if focusMode == .autoFocus && exposureMode == .autoExpose  {
            //.autoFocus 1 手动
          //.autoExpose 1 手动
          self.setFocusBoxPointInternal(point, focusMode: focusMode, exposureMode: exposureMode)

        }
    }
    /**摄像头焦点设置**/
    private func setFocusBoxPointInternal(_ point: CGPoint, focusMode: AVCaptureDevice.FocusMode, exposureMode: AVCaptureDevice.ExposureMode) {
        
        Task {
            guard let mixer = self.mixer else {
                return
            }
            try await mixer.configuration(video: 0) {unit in
                guard let device = unit.device else {
                    return
                }
                TFIngestTool.focusPoint(point, focusMode: focusMode, exposureMode: exposureMode, device: device)
            }
        }
    }

    // MARK: - 视频的时间戳数据
    @objc public func sendData(_ text: String)
    {
//        NSString *time = [NSString stringWithFormat:@"disposeTime:%0.1f",self.disposeTime];
        
    }
    //TODO: 关闭SDK
    @objc public func shutdown()
    {
        Task {
            guard let mixer = self.mixer else {
                return
            }
            //结束录制
            self.recording(false)
            //结束推流
            preference.shutdown()
            await mixer.stopRunning()
            await mixer.stopCapturing()
            try? await mixer.attachAudio(nil)
            try? await mixer.attachVideo(nil, track: 0)
            
            if let stream = preference.stream()
            {
                await mixer.removeOutput(stream)
            }
            self.mixer = nil
         
            NotificationCenter.default.removeObserver(self)
        }
       
    }
     func startLiveCallback(_ callback: ((Int, String) -> Void)?,code:NSInteger,msg:String)
    {
        DispatchQueue.main.async {
            self.preference.pause = false
            if let callback = callback {
              
                callback(code,msg)
            }
            
        }
    }
}
