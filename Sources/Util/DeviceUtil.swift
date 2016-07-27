import Foundation
import AVFoundation

public class DeviceUtil {
    private init() {
    }

    #if os(iOS)
    static public func getAVCaptureVideoOrientation(orientation:UIDeviceOrientation) -> AVCaptureVideoOrientation? {
        switch orientation {
        case .Portrait:
            return .Portrait
        case .PortraitUpsideDown:
            return .PortraitUpsideDown
        case .LandscapeLeft:
            return .LandscapeRight
        case .LandscapeRight:
            return .LandscapeLeft
        default:
            return nil
        }
    }
    #endif

    static public func deviceWithPosition(position:AVCaptureDevicePosition) -> AVCaptureDevice? {
        for device in AVCaptureDevice.devices() {
            guard let device:AVCaptureDevice = device as? AVCaptureDevice else {
                continue
            }
            if (device.hasMediaType(AVMediaTypeVideo) && device.position == position) {
                return device
            }
        }
        return nil
    }

    static public func deviceWithLocalizedName(localizedName:String, mediaType:String) -> AVCaptureDevice? {
        for device in AVCaptureDevice.devices() {
            guard let device:AVCaptureDevice = device as? AVCaptureDevice else {
                continue
            }
            if (device.hasMediaType(mediaType) && device.localizedName == localizedName) {
                return device
            }
        }
        return nil
    }

    static func getActualFPS(fps:Float64, device:AVCaptureDevice) -> (fps:Float64, duration:CMTime)? {
        var durations:[CMTime] = []
        var frameRates:[Float64] = []
        
        for object:AnyObject in device.activeFormat.videoSupportedFrameRateRanges {
            guard let range:AVFrameRateRange = object as? AVFrameRateRange else {
                continue
            }
            if (range.minFrameRate == range.maxFrameRate) {
                durations.append(range.minFrameDuration)
                frameRates.append(range.maxFrameRate)
                continue
            }
            if (range.minFrameRate <= fps && fps <= range.maxFrameRate) {
                return (fps, CMTimeMake(100, Int32(100 * fps)))
            }
            
            let actualFPS:Float64 = max(range.minFrameRate, min(range.maxFrameRate, fps))
            return (actualFPS, CMTimeMake(100, Int32(100 * actualFPS)))
        }
        
        var diff:[Float64] = []
        for frameRate in frameRates {
            diff.append(abs(frameRate - fps))
        }
        if let minElement:Float64 = diff.minElement() {
            for i in 0..<diff.count {
                if (diff[i] == minElement) {
                    return (frameRates[i], durations[i])
                }
            }
        }
        
        return nil
    }
}
