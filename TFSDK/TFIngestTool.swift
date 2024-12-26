//
//  TFIngestTool.swift
//  TFSRT
//
//  Created by moRui on 2024/12/26.
//

import UIKit
import HaishinKit
import Photos
import UIKit
import VideoToolbox
import Combine
class TFIngestTool: NSObject {
    class func setEnabledPreferredInputBuiltInMic(_ isEnabled: Bool) {
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
    class func extractLastPathComponent(from urlString: String) -> String? {
        if let urlComponents = URLComponents(string: urlString),
           let path = urlComponents.path.split(separator: "/").last {
            return String(path)
        }
        return nil
    }
    // 3. 将 SampleBuffer 创建逻辑分离到独立函数
    class func createSampleBuffer(from pixelBuffer: CVPixelBuffer) async throws -> CMSampleBuffer {
            // 4. 使用精确的时间戳计算
            let timestamp = CACurrentMediaTime()
            var timingInfo = CMSampleTimingInfo(
                duration: CMTime(value: 1, timescale: 30),
                presentationTimeStamp: CMTime(seconds: timestamp, preferredTimescale: 600),
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
                throw NSError(domain: "VideoProcessing", code: Int(formatStatus), userInfo: nil)
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
                throw NSError(domain: "VideoProcessing", code: Int(createStatus), userInfo: nil)
            }
            
            return buffer
        }
    
    
    class func focusPoint(_ focusPoint: CGPoint,
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
    
    class func callback(_ callback: ((Int, String) -> Void)?,code:NSInteger,msg:String)
    {
        DispatchQueue.main.async {
            if let callback = callback {
                callback(code,msg)
            }
            
        }
    }
}
